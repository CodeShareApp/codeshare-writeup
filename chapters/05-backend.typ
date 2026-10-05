#import "../lib.typ": *

= The backend

`backend/` is a separate Go module comprising about 3,500 lines of hand-written Go (generated code
excluded) and 42 test functions, mostly integration tests against a real PostgreSQL instance (each
package receives its own schema; without `TEST_DATABASE_URL` the tests are skipped).

== Contract-first design

The API is specified in `backend/api/openapi.yaml`. `mise run gen` runs oapi-codegen with the
`echo5-server` and `strict-server` generators, producing `internal/api/api.gen.go`: request and
response types per operation and a `StrictServerInterface` with one typed method per endpoint.
Generated files are never edited.

The principal benefit of the strict server is that *every response is a type*. A handler cannot return a 409
without the 409 body the spec declares; adding a response code to the spec breaks the build until
a handler produces it. In a plain Echo handler, by contrast, a status code is merely an integer.

There is one intentional exception: the passkey routes (`/auth`, `/api/auth/*`) are handwritten, as in
holy-shit-api, because go-webauthn reads the WebAuthn JSON straight from the raw `*http.Request`,
which strict request objects cannot provide. The development sign-in route is likewise excluded
from the spec.

== Layers

#fig(
  canvas(40mm, {
    node(0mm, 2mm, 30mm, 16mm)[`internal/api` \ generated \ (strict interface)]
    node(36mm, 2mm, 30mm, 16mm)[`internal/server` \ auth + DTO mapping \ no business logic]
    node(72mm, 2mm, 30mm, 16mm)[`internal/service` \ rules, transactions]
    node(108mm, 2mm, 28mm, 16mm)[`internal/repository` \ multi-table SQL]
    node(72mm, 26mm, 64mm, 11mm, stroke: c.muted)[`internal/db` (sqlc, pgx/v5) → PostgreSQL 18]
    arrow((30mm, 10mm), (36mm, 10mm))
    arrow((66mm, 10mm), (72mm, 10mm))
    arrow((102mm, 10mm), (108mm, 10mm))
    arrow((87mm, 18mm), (87mm, 26mm))
    arrow((122mm, 18mm), (122mm, 26mm))
    label(89mm, 20mm)[simple CRUD]
  }),
  [Backend layering. Services may call sqlc directly for simple CRUD; anything transactional or
  multi-table goes through a repository.],
)

The server layer is intentionally minimal: it authenticates, maps, calls one service method and
maps errors to typed responses. The complete error mapping of the `PUT /api/codes/{id}` handler is
shown below; typed errors from the service become the spec's 409 and 422 bodies:

```go
code, err := s.codes.Put(ctx, user.ID, service.CodeInput{ /* … from b */ })
if dup, ok := errors.AsType[*service.DuplicateError](err); ok {
    return api.PutCode409JSONResponse{Error: dup.Error(),
        ExistingId: dup.ExistingID}, nil
}
if old, ok := errors.AsType[*service.OldKeyError](err); ok {
    return api.PutCode422JSONResponse{Error: old.Error(),
        CurrentKeyVersion: old.Current}, nil
}
switch {
case errors.Is(err, service.ErrNoHousehold):
    return api.PutCode403JSONResponse{ /* … */ }, nil
case errors.Is(err, service.ErrNotFound):
    return api.PutCode404JSONResponse{ /* … */ }, nil
case err != nil:
    return nil, err   // 500, logged once at ERROR by server.ErrorHandler
}
return api.PutCode200JSONResponse(codeDTO(code)), nil
```

== Schema

The schema is defined by three goose migrations, embedded in the binary (`codeshare-api migrate`). Every primary key that
the server generates defaults to `uuidv7()`; code ids come from the phones.

#dtable(
  columns: (0.7fr, 2fr),
  header: ("Table", "Purpose and notable constraints"),
  [`users`], [Username unique case-insensitively. Not encrypted at rest, unlike holy-shit's: a small number of known users, and the valuable data is end-to-end encrypted regardless.],
  [`credentials` \ `webauthn_sessions` \ `auth_codes`], [Passkeys; ceremonies in flight (5 min); one-time codes from the sign-in redirect (1 min).],
  [`sessions`], [Bearer tokens stored as SHA-256, so a leaked backup signs nobody in. No expiry; `DELETE /api/me/session` revokes.],
  [`households` \ `members`], [`key_version` ≥ 1. `members.user_id` UNIQUE: one household per user. Any number of members: the original `MaxMembers = 2` cap is being removed.],
  [`devices`], [A phone's public key, 65 bytes (`CHECK octet_length = 65`), unique *per user*, not globally.],
  [`key_wraps`], [PK (household, key version, device). `wrapped_key` ≤ 256 bytes (a wrap is 92); ephemeral key 65 bytes.],
  [`stores`], [Global, PK `filiaal_nr`. `location_source` `pdok` | `client`; CHECKs tie lat/lng/source together. `created_by` for the per-user limit. `xid` for sync.],
  [`codes`], [`sealed` (1 B–16 KiB), `nonce` (12 B), `key_version`, `payload_mac` (32 B), plaintext kind/store/status/timestamps, `client_updated_at` (the LWW clock), `xid`. UNIQUE `(household_id, payload_mac)`.],
  [`database_generation`], [A singleton uuid, part of every sync cursor (@sec-cursor).],
)

The database checks lengths; the service checks meaning (a public key must be a point on the
curve, an id must be a UUIDv7, `updatedAt` may not be more than 24 hours in the future, since a phone
with a faulty clock would otherwise protect a code against every later edit).

== Authentication

Authentication is ported from holy-shit-api: a WebAuthn page at `GET /auth` (static HTML), ceremonies via
go-webauthn, the redirect to `codeshare://auth?code=`, and `POST /api/auth/token` exchanging the
one-time code for a random 32-byte bearer token. The Relying Party ID is `codeshare.shop`.

The dev sign-in route (`POST /api/dev/session?username=`, passkey-free, for the Simulator) is the
only component that would render the server trivially insecure, so it is compiled in only with
`-tags DEV`. holy-shit-api does the reverse (enabled unless `-tags PROD`); review inverted this so
that *an omitted tag fails safe*. The release script additionally runs
`TestReleaseBinaryHasNoDevSession` and searches the built binary for the route string, aborting
the release if it is present.

== Stores, PDOK and address squatting <sec-stores>

Stores are global facts keyed by filiaal number: every household that has a bon from store 4520
refers to the same row. The address is *immutable once stored* (the first bon prevails), and a later
`PUT /api/stores/{filiaalNr}` answers 200 with the stored row for the client to adopt. This
decision was taken by the owner and supersedes two earlier review fixes that allowed edits to
overwrite addresses: a misread on a later bon must never replace a correct address, and correcting
a wrong one is a rare manual `UPDATE`.

Global, immutable, first-writer-wins rows invite squatting once signup is open: a stranger could
claim every filiaal number with an incorrect address. Two defences are in place:

- *At most 10 new stores per user per 24 hours*, counted in PostgreSQL (`created_by`,
  `created_at`) under a per-user advisory lock so that concurrent requests cannot both pass under
  the limit; 429 beyond. Updating an existing store is not limited.
- *A new store's address must geocode via PDOK inside the Netherlands*, else 400. PDOK queries are
  restricted to the postcode (`fq=postcode:2511AB`), so a street name that exists in many towns
  cannot match the wrong one.

If PDOK is *unreachable*, the store is saved unverified and geocoded on a later PUT. Refusal would
prevent a bon from being saved in the shop whenever a government service is unavailable, which is
more harmful than a rare unverified address that remains rate-limited. PDOK coordinates replace a client's
MapKit coordinates once and are never overwritten; PDOK points with NaN, infinities or outside the
Netherlands' bounding box are refused (a review finding: NaN fails every comparison, so a
bounding-box check written as "reject if outside" must be written as "accept only if inside").

#note(title: "Superseded (specified)")[Global store rows, their squatting defences and the
server's PDOK lookups are to be replaced by sealed per-household stores (@sec-sealed-stores),
because a store linked to the user who registered it reveals where that user shops.]

== Protecting a shared database

Open signup also means that anyone can call the unauthenticated passkey routes, and some of them
insert rows (a WebAuthn ceremony per `login/begin`, a user per `signup`). On a shared PostgreSQL
instance this is a disk-exhaustion vector for every application on the host. Review added: expired ceremonies and codes purged on
every insert and at startup; `/api/auth/*` limited to 20 requests a minute per client IP and signup
to 5 an hour (token buckets in memory); and the client IP taken from `X-Forwarded-For` only as
appended by Caddy on loopback, so that the limit cannot be evaded by spoofing the header. Request bodies
are capped at 64 KiB.

== Error reports and telemetry

`internal/telemetry` is holy-shit-api's port of medic-go's, kept diffable. Logs go to stderr as
JSON lines; with `TELEMETRY_ENABLED`, logs, traces and metrics also go over OTLP to CloudWatch,
where a Lambda e-mails *every ERROR*. The log level is therefore an alerting decision, and the
rule is strict: ERROR only for 5xx (logged once by `server.ErrorHandler`), fatal startup errors and app
crashes; client errors (4xx) are WARN or lower. The following are never logged: tokens, auth codes, query strings,
usernames (user ids instead), sealed blobs, public keys.

The app reports problems to `POST /api/client-errors` (signed in only): a fixed message, an error
type and status code, app and OS version; at most 2 KiB, 30 per user per hour. Review removed the
server's error text from these reports, so that no server-generated text can be reflected back.
