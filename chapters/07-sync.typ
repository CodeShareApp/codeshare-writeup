#import "../lib.typ": *

= Sync

The sync problem comprises several phones, each holding a full local database, possibly offline
for days, editing the same codes. The design adopts the simplest model that is correct for this
data: *last write wins per code, on the client's clock, with soft deletes*. A code has few fields,
and the members of a household rarely edit the same voucher at the same moment; field-level merging
would provide no benefit.

== The cursor: transaction ids, not timestamps <sec-cursor>

`GET /api/sync?since=` returns every code (tombstones included) and every referenced store changed
since a cursor. The obvious cursor, `updated_at`, is incorrect for two reasons:

- The *client's* `updatedAt` is skewed across phones. It is adequate for deciding which edit wins
  but unsuitable for ordering what the server has received.
- The *server's* `now()` is the transaction's *start* time. A transaction that starts before a sync
  but commits after it carries an `updated_at` below that sync's cursor and is missed permanently. A
  sequence has the same defect: numbers are allocated in start order, while rows become visible in
  commit order.

The cursor is instead a PostgreSQL transaction id. Every write sets the row's `xid8` column to
`pg_current_xact_id()`. A sync runs in one `REPEATABLE READ`, read-only transaction and returns the
rows with `xid >= since` plus the snapshot's *xmin* (the oldest transaction still running when the
snapshot was taken) as the next cursor:

```sql
-- name: SnapshotXmin :one
SELECT pg_snapshot_xmin(pg_current_snapshot())::xid8 AS xmin;

-- name: CodesChangedSince :many
SELECT * FROM codes
WHERE household_id = sqlc.arg(household_id) AND xid >= sqlc.arg(since)::xid8
ORDER BY xid, id;
```

Every transaction below xmin had finished, so whatever it committed was visible to this sync; every
transaction that commits later has an id ≥ xmin, so the next sync observes it. The cost is that some
rows are returned more than once, which last-write-wins renders harmless. `xid8` is 64 bits and never wraps.

=== Restores and the database generation

Transaction ids are meaningful only within one cluster. When a dump is restored elsewhere, the rows
retain their old `xid` values while the counter restarts, so a phone's cursor could skip new writes
for an extended period. Review identified this defect; the cursor is now `<generation>:<xid>`, where the generation is
a uuid in a singleton table that is changed manually after a restore
(`UPDATE database_generation SET id = uuidv7()`). A cursor of another generation, or one *ahead* of
the transaction counter (in case that step is omitted), triggers a full resync with `full: true`.

== Push, then pull

#fig(
  canvas(66mm, {
    node(0mm, 0mm, 40mm, 10mm)[① PUT unsynced stores]
    node(0mm, 16mm, 40mm, 10mm)[② PUT dirty codes, sealed]
    node(0mm, 32mm, 40mm, 10mm)[③ GET /api/sync?since=]
    node(0mm, 48mm, 40mm, 12mm)[④ open, merge LWW, \ advance cursor]
    arrow((20mm, 10mm), (20mm, 16mm))
    arrow((20mm, 26mm), (20mm, 32mm))
    arrow((20mm, 42mm), (20mm, 48mm))
    node(56mm, 0mm, 80mm, 10mm, stroke: c.muted, size: 7.4pt)[200 adopt server's copy · 400 (PDOK refused) mark done · 429 later]
    node(56mm, 13mm, 80mm, 8mm, stroke: c.accent, size: 7.4pt)[200 stored → clean (unless edited meanwhile)]
    node(56mm, 23mm, 80mm, 8mm, stroke: c.amber, size: 7.4pt)[409 `existingId` → re-key local row, PUT again]
    node(56mm, 33mm, 80mm, 8mm, stroke: c.amber, size: 7.4pt)[422 `currentKeyVersion` → fetch wraps, reseal, PUT]
    node(56mm, 43mm, 80mm, 8mm, stroke: c.red, size: 7.4pt)[403 no household · 400/404 stays dirty, reported]
    node(56mm, 54mm, 80mm, 10mm, stroke: c.muted, size: 7.4pt)[`full: true` → rows the server lost are marked dirty and re-pushed]
    arrow((40mm, 5mm), (56mm, 5mm))
    arrow((40mm, 21mm), (56mm, 17mm))
    arrow((40mm, 21mm), (56mm, 27mm))
    arrow((40mm, 21mm), (56mm, 37mm))
    arrow((40mm, 21mm), (56mm, 47mm))
    arrow((40mm, 54mm), (56mm, 59mm))
  }),
  [One sync pass (`SyncEngine.sync`). The pass is offline-safe: any failure leaves rows dirty and
  the cursor unchanged, and the next pass resumes.],
) <fig-sync>

`SyncController` runs a pass on returning to the foreground, 2 seconds after the last local edit
(debounced), on pull-to-refresh and when the household becomes ready. The free account has no push,
so this is the mechanism by which the other members' changes arrive. A pass requested during a
running pass is executed once more afterwards.

=== Dirty tracking

Every UI write sets `codes.dirty = 1`; only the sync engine writes clean rows. `markPushed` clears
`dirty` only if the row's `updated_at` still equals the value sent; an edit made while the request
was in flight leaves it dirty. Stores carry `server_synced` instead, since their address is
immutable after the first write.

=== 409: adopt the server's id

The same bon scanned on two phones while offline produces two ids for one payload. The second PUT
violates the server's unique `(household_id, payload_mac)` and receives 409 with `existingId`. The
phone *re-keys* its local row to the server's id and repeats the PUT under that id (which revives the
code if it was deleted and the local copy is newer). The pull side has the symmetric case: a server
code whose payload is held by a different local row. The server's id prevails; the local row is
re-keyed if it is a newer dirty edit and dropped otherwise.

=== 422: another phone rotated the key

A PUT sealed under an older key version is refused with `currentKeyVersion`. The phone fetches its
wraps, accepts the new version only if it is authenticated by the previous one, reseals, and retries
(at most twice).

== Last write wins, and replays <sec-lww>

The merge decision is a pure function, tested in isolation:

```swift
static func decide(local: SyncRecord?, serverUpdatedAt: Date) -> Decision {
    guard let local else { return .applyServer }
    return local.code.updatedAt.milliseconds > serverUpdatedAt.milliseconds
        ? .keepLocal : .applyServer
}
```

The comparison is in whole milliseconds on both sides, because two parsers of the same timestamp
may differ in the last bits of a `Double`, and a tie must denote the same edit.

The first version applied any server row to a *clean* local row; only dirty rows prevailed locally.
Review identified the attack: a server replays an older but authentic sealed blob and reverts a
code's used or deleted state. The local row now prevails whenever it is newer, clean or dirty. A
follow-up finding completed the fix: when a newer clean local row is kept, it is marked dirty, so
that the next push restores the newer state on the server (and on the other members' phones).

== Sign-out and the generation counters

Sign-out was the location of the most subtle defects.

*Re-sealing another household's codes.* The first sign-out marked every code dirty with no
household, so whatever account signed in next would seal household A's codes (including those of
the other members) into its own household and upload them. Sign-out now *deletes* every row a household synced (they are restored
from the server via this device's wraps on the next sign-in), keeps only never-synced rows, and a
push only ever takes rows of the current household or of none:

```swift
func resetSyncState() throws {
    try writer.write { db in
        try db.execute(sql: """
            DELETE FROM codes WHERE household_id IS NOT NULL;
            UPDATE stores SET server_synced = 0;
            DELETE FROM sync_state;
            """)
    }
}
```

*Responses from a previous session.* Network calls outlive the screen that initiated them. A sync pass, a
wrap fetch or the 3-second join poll still running at sign-out could write an old household key, an
old device id or old rows after the reset, or, after a quick sign-in as another user, send the new
account's token for the old pass. Three review findings introduced *generation counters*:
`SyncGeneration` is incremented by sign-out; every pass receives an API client bound to the token it
started with and checks its generation *inside every write transaction*; `HouseholdKeys` writes keys and the
device id only under the same lock that `forget()` takes, after re-checking the generation.

#lesson[Every `await` is a point at which external state may have changed. In a client with
sign-out, any state written after an `await` requires a check that the session is still the one in
which the operation started, performed atomically with the write.]

*Sign-out versus "account gone".* A chosen sign-out drops synced rows, as above. A *401* on any
request now signifies "account gone" (`SignOutReason.accountGone`) and has the opposite effect:
every code is retained, re-tagged as never synced, for the next household to adopt. The distinction
originates in a server wipe, described in the next chapter.
