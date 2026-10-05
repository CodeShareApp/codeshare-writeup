#import "../lib.typ": *

= Sealed stores: metadata at rest <sec-sealed-stores>

A *specification* that changes built behaviour. The design so far treats a store as a global
fact: its address is printed on every bon, so the server keeps one plaintext row per store for
all households (@sec-stores). That reasoning is right about the address and wrong about the *association*. The
address of a supermarket is public; the fact that a particular household holds vouchers for it,
first registered it on a Tuesday evening, and redeems there every Saturday is not. Store data is
therefore to be encrypted at rest, not because it is secret, but because its links to users are.

== What the current design reveals

#dtable(
  columns: (auto, 1fr),
  header: ("Where", "What the server learns"),
  [`codes` plaintext store column], [Which stores each household uses, how many vouchers it holds per store, and (with the status and timestamps) when it shops where.],
  [`stores.created_by`], [Which *user* first scanned a bon at a store: for a small or local store, close to where that person lives or works.],
  [The per-user store limit], [A count of new stores per user per day, kept for exactly that link.],
  [Server-side PDOK lookups], [Each new store's postcode, at the moment a particular user saves it, in the request log.],
  [`GET /api/sync`], [Returns "every referenced store", that is the household's store list, assembled by the server.],
)

None of this is needed for what the server does: relaying, ordering and deduplicating sealed
records. The threat model lists "for which stores" under traffic analysis that is *not*
defended (@sec-threats). This change moves it to the defended side.

== Design

Stores become *household records*, sealed with the household key exactly like codes:

+ *Sealed store rows.* A new table `household_stores` holds per household: `id` (UUIDv7),
  `sealed`, `nonce`, `key_version`, `store_mac`, `client_updated_at`, `xid`. The sealed content
  carries chain, store key (filiaal number, or the address key of @sec-rewe), label, address,
  coordinates and their source. The AAD binds it to row id, household and key version, as for
  codes.
+ *Deduplication by blind index.* `store_mac` = HMAC-SHA256 over chain and store key, under a
  third HKDF subkey (`info` `codeshare/v1/store-mac`, salt the household id), so that two phones
  that scan the same store independently converge on one row (`UNIQUE (household_id,
  store_mac)`, with the same 409 "adopt the server's id" as codes). The MAC
  is per household: equal stores in two households give unrelated values, so the server cannot
  join households by store.
+ *Codes lose their plaintext store.* The store reference lives only in the code's sealed content,
  which already carries it (`filiaalNr` in version 2; a store id in version 3). The plaintext
  column is dropped.
+ *The global `stores` table is dropped*, and with it `created_by`, the per-user limit, the
  advisory lock and the server's PDOK and Nominatim lookups. Squatting was a problem of shared
  mutable rows; a household can now only mislabel its own stores.
+ *Geocoding moves to the phone.* `StoreLocator` already geocodes with MapKit. For Dutch
  addresses the phone may also ask PDOK directly (a public service without accounts): PDOK sees an
  IP address and a postcode, not a user or household. German addresses use MapKit, which also
  removes the need for a server-side German geocoder (@sec-rewe).
+ *Address rules stay, locally.* The first bon still prevails, and a later bon's reading never
  overwrites a stored address. Because a wrong address now harms only the household that entered
  it, a member may correct one by hand, which replaces the manual `UPDATE` of the global design.
+ *Sync and rotation.* Store rows ride the same cursor, last-write-wins and dirty tracking as codes
  (replacing the stores' `server_synced` flag), and an eager rotation reseals and re-MACs them
  with the codes (@sec-rotation).

=== Why not encryption at rest on the server

Encrypting the database files, or the store columns under a server-held key, protects a stolen
disk or backup. Backups are already encrypted (`pg_dump` to S3), and the running server would
still read every association. Only a key the server does not hold removes the link, and the
household key is that key.

=== Cost

- Households no longer share geocoded addresses: each geocodes its own stores, a handful of
  requests a year.
- The server can no longer validate an address against PDOK. That check existed only to protect
  the global rows from other users, which no longer exist.
- Grouping and distance sorting were already done on the phone (`StoreProximity`); nothing on
  the home screen depends on the server knowing stores.

== The same principle, beyond stores

The argument applies to every plaintext column that the server keeps "only for sync". Of those,
the server *uses* only the code id, household, `payload_mac` (deduplication) and
`client_updated_at` (last-write-wins). *Kind*, *status* and the *issue, used and delete
timestamps* are not used by the server, and reveal metadata in the same way: kind `parking` or
`boarding` (@sec-parking, @sec-boarding) says that a household parks bikes or flies, and a
voucher's `usedAt` is the time someone stood at a till. They move into the sealed content only
(they are already sealed copies; phones already trust only those, @sec-sealed-meta), and the
plaintext columns are dropped.

What remains visible to the server after both changes:

#dtable(
  columns: (1fr, 1fr),
  header: ("Still visible", "Why"),
  [Households, members, devices, wraps], [Needed to route keys and authorise requests.],
  [Number of codes and stores, and blob sizes], [Inherent in storing them; padding is possible but not planned.],
  [When rows are written (`client_updated_at`, commit order)], [Last-write-wins and the cursor. Ordering by version numbers instead of client times would remove the clock but not the commit order.],
  [IP addresses of requests], [Inherent in a server; not logged beyond the access log's retention.],
)

== Rollout

The glowie-curve backend is to be deployed with a database wipe (@sec-wipe). This change goes
into the same release, so no server data has to be migrated: phones upload their stores as
sealed rows on the first push to the wiped server, as they upload their codes. The local
database gains a migration that adds chain and store key to stores and replaces
`server_synced` with the codes' dirty flag.

#lesson[The first design asked "is this value secret?" and, finding a public address, stored it
in plaintext. The better question is the one review applied to the code metadata (the server
could change it to the household's detriment): *what does this value reveal in combination with
who stores it?* A public fact attached to a user is a private fact about the user.]
