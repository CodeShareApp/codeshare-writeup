#import "../lib.typ": *

= The review process and what it caught

== How the work was organised

The entire project, from a plan drafted in a claude.ai chat to a deployed backend and an
end-to-end-encrypted app, was built with Claude Code, Anthropic's AI coding agent: one main
session orchestrating background agents, directed and reviewed by the author, who decided the
requirements and the trade-offs and tested on real phones and at the till. This report was
produced the same way. The
author timestamps of all commits fall on 2 October 2026. The work was organised as follows:

- *Separate jj workspaces per stream*: `workspaces/ios`, `workspaces/backend`, `workspaces/widget`
  (later `landing`) under the project folder, git-ignored. Each agent works in its own checkout, so
  parallel streams never interfere with one another's working copy. (They were first created as siblings in
  `~/working`; they were moved under `workspaces/`, and "workspaces live inside the project" became
  a global rule.)
- *Every substantial change receives an independent adversarial review* before it is merged,
  deployed or installed. The reviewer is a fresh agent that did not write the code, instructed to
  verify every claim against the code and to state explicitly when a suspicion does not survive
  verification.
- *Each surviving finding is fixed in its own commit*, with "Found in review." and the reason in the
  message. Of roughly 120 commits, 55 carry that line. The history therefore also serves as a
  catalogue of defects and their fixes, and this chapter is largely derived from it.
- *Merges are rebases into one linear line.* Conflicts in the String Catalog (a large JSON file modified
  by both streams) were resolved semantically, by merging the two key sets as JSON, rather than by
  editing conflict markers in a 50 KB file.
- *The owner's decisions take precedence over review.* When review proposed allowing edits to
  overwrite a store address and the owner decided that addresses are immutable, the decision commit
  recorded that it supersedes two review fixes.

== The findings that mattered most

#dtable(
  columns: (1.25fr, 1.25fr, 1fr),
  header: ("Finding", "Fix", "Lesson"),
  [*Sign-out re-sealed household A's codes* (other members' included) into whatever household signed in next.], [Sign-out deletes rows a household synced; pushes take only the current household's or never-synced rows.], ["Forget" must mean delete, not "mark for re-upload".],
  [*Unauthenticated wraps*: a malicious server could supply a phone with its own K′ at join or via a fake rotation.], [HMAC tag on every wrap, keyed by the QR secret, K#sub[n], or the device key; unwrap only verified wraps.], [Trusting the camera protects the sender, not the receiver.],
  [*Metadata outside the AEAD*: server could mark used, delete, roll back, move stores.], [Sealed content v2 carries kind, store, status, timestamps; phones trust only it.], [Anything the server could change to the household's detriment belongs inside the AEAD.],
  [*Replay* of an older authentic blob could revert a code to unused.], [Local row wins when newer, clean or dirty; and is re-pushed.], [Authenticity is not freshness.],
  [*Joiner never self-wrapped*: after sign-out it could not recover K.], [Self-wrap before forgetting the QR secret; live test signs out and back in.], [The second session requires testing, not only the first.],
  [*Stale async answers* after sign-out could store old keys, ids or rows.], [Generation counters checked inside write transactions; token-pinned clients.], [Every `await` is a session boundary.],
  [*Rotation wrapped to every registered device*, including one registered with a stolen session.], [Rotate to exactly the key holders.], [Registration is not membership.],
  [*Device-key squatting*: globally unique keys, first come first served.], [Keys unique per user; wraps name device id + key.], [Uniqueness constraints are also claims.],
  [*Open signup + global stores* invites address squatting.], [10 new stores/user/day under an advisory lock; PDOK must find the address in NL.], [Shared mutable facts need an abuse budget.],
  [*xid cursor after dump/restore* is meaningless.], [Cursor carries a database generation; ahead-of-counter forces full resync.], [A cursor should encode the assumptions it depends on.],
  [*mac_key rotates with K*: old MACs escape dedupe.], [Eager rotation; server refuses older key versions (422).], [Derived keys inherit their parent's lifecycle.],
  [*Dev sign-in route* on unless a tag was set.], [Opt-in with `-tags DEV`; release script greps the binary.], [Omissions should fail safe.],
  [*PDOK NaN coordinates* passed an "outside" check.], [Accept only points inside the NL bounding box.], [Range checks are written as "accept if inside".],
  [*Unauthenticated auth routes* could fill the shared Postgres disk.], [Purge expired rows; per-IP rate limits with trusted XFF only.], [On a shared host, abuse of one service causes an outage for all.],
  [*Simulator-only erase guarded by `DEBUG`*, although phones run Debug.], [`#if targetEnvironment(simulator)`.], [The build configuration actually running on the device must be known.],
  [*Camera permission* never requested on fresh install.], [Request access before checking `isAvailable`.], [API preconditions must be read.],
  [*Out-of-range key version* crashed the app.], [`UInt32(exactly:)`, throw.], [Server input must never cause a trap.],
  [*Keychain read failure* treated as "no key".], [Only a key actually read is acted upon.], [Absence and failure are different answers.],
)

== Reviewing the review

Not every suspicion survived verification, and the review briefs required this to be stated. The
surviving findings exhibit several patterns:

- *Most serious findings concerned trust boundaries* rather than code quality: which party vouches
  for a wrap, which fields the server can modify, which device receives a key. Review that asks
  "what can the server do?" yields more findings than review that asks "is this code clean?".
- *Most of the remainder concerned lifecycles*: sign-out, restore, rotation, a migration on a Debug
  build, a database file moving between containers. The primary path was usually correct at the
  first attempt.
- *Fixes were accompanied by tests that fail without them*: the joiner self-wrap, the replay rule, the release
  binary check, Go-computed crypto vectors with negative tests for substituted wraps.

#lesson[Adversarial review is most effective before a merge is requested, not after. A finding
deferred to a later round costs a full round, and the code remains defective in the meantime. In
this project review ran on every substantial change and produced at least one finding in almost
every instance.]
