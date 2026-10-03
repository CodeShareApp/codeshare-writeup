#import "../lib.typ": *

= Architecture overview

CodeShare is *local-first*. Each phone holds a complete SQLite database and functions without any
network connection; the server acts as a relay and a backup that stores, orders and returns
encrypted blobs but cannot read them. @fig-arch shows the components.

#fig(
  canvas(96mm, {
    // phone A
    node(0mm, 0mm, 54mm, 94mm, [], fill: none, stroke: c.hair, dash: "dashed", radius: 6pt)
    label(3mm, 1.6mm, text(fill: c.accent, weight: "semibold")[A member's iPhone])
    node(4mm, 8mm, 46mm, 9mm)[SwiftUI views · `Theme`]
    node(4mm, 22mm, 46mm, 9mm)[`CodeStore` (ObservableObject)]
    node(4mm, 36mm, 46mm, 11mm)[`AppDatabase` \ GRDB · SQLite · migrations]
    node(4mm, 54mm, 46mm, 9mm)[`SyncEngine` (actor)]
    node(4mm, 68mm, 46mm, 9mm)[`HouseholdService` · `KeyRing`]
    node(4mm, 81mm, 46mm, 9mm, fill: c.deep, stroke: c.accent)[Secure Enclave: device key]
    arrow((27mm, 17mm), (27mm, 22mm), both: true)
    arrow((27mm, 31mm), (27mm, 36mm), both: true)
    arrow((27mm, 47mm), (27mm, 54mm), both: true)
    arrow((27mm, 68mm), (27mm, 63mm))
    label(28.5mm, 63.6mm)[keys]
    arrow((27mm, 81mm), (27mm, 77mm))
    // server
    node(62mm, 0mm, 52mm, 72mm, [], fill: none, stroke: c.hair, dash: "dashed", radius: 6pt)
    label(65mm, 1.6mm, text(fill: c.muted, weight: "semibold")[Shared FreeBSD server])
    node(66mm, 9mm, 44mm, 11mm)[Caddy · TLS \ `codeshare.shop`]
    node(66mm, 28mm, 44mm, 15mm)[`codeshare-api` (Go) \ Echo v5 strict server \ server → service → repository]
    node(66mm, 52mm, 44mm, 14mm)[PostgreSQL 18 \ sealed codes · wraps · stores]
    arrow((88mm, 20mm), (88mm, 28mm))
    arrow((88mm, 43mm), (88mm, 52mm), both: true)
    path-arrow((50mm, 58.5mm), (57.5mm, 58.5mm), (57.5mm, 14.5mm), (66mm, 14.5mm), color: c.accent)
    // right column
    node(118mm, 6mm, 18mm, 22mm, stroke: c.muted)[Members' iPhones \ (same app)]
    arrow((118mm, 14.5mm), (110mm, 14.5mm), color: c.accent)
    node(118mm, 34mm, 18mm, 10mm, stroke: c.muted)[PDOK]
    node(118mm, 49mm, 18mm, 10mm, stroke: c.muted)[CloudWatch]
    node(118mm, 64mm, 18mm, 10mm, stroke: c.muted)[S3 backups]
    arrow((110mm, 35.5mm), (118mm, 39mm))
    arrow((110mm, 40mm), (118mm, 53mm))
    arrow((110mm, 62mm), (118mm, 68mm))
    // legend
    label(62mm, 77mm, w: 74mm)[#text(fill: c.accent)[━] HTTPS, bearer token: sealed blobs, wraps, public keys, plaintext metadata. \
      #text(fill: c.muted)[━] server-side calls: geocoding new stores, OTLP telemetry, encrypted `pg_dump`.]
  }),
  [The system. All components inside the phone function offline; only the sync engine and the
  household service communicate with the server.],
) <fig-arch>

== The phone

- *`AppDatabase`* owns the SQLite file and performs every write. It is the only component on the
  phone that contains SQL. Migrations are plain SQL (@sec-grdb).
- *`CodeStore`* observes the database with GRDB's `ValueObservation` and publishes a
  `LibrarySnapshot` (live codes and all stores) to SwiftUI. Views do not query; they render the
  snapshot and call `CodeStore` to write.
- *`SyncEngine`* is an actor that pushes dirty rows sealed and pulls changes, one pass at a time
  (Chapter 7). `SyncController` decides when to run it.
- *`HouseholdService`* enrols the phone in a household and obtains the household key for it;
  *`KeyRing`* keeps that key and the device key's handle in the Keychain; the private device key
  itself resides in the *Secure Enclave* (Chapter 6).
- *`StoreLocator`* geocodes stores on-device with MapKit; *`LocationProvider`* and the pure
  `StoreProximity` sort stores by distance and detect presence at a store.

== The server

The server is a single Go binary, `codeshare-api`, behind Caddy. It authenticates users
(passkeys), maintains households, members, devices and key wraps, stores codes as sealed blobs
with a small number of plaintext columns, maintains a global table of stores, and answers
`GET /api/sync` with a transaction-id cursor. It performs *no cryptography* on code contents and
never receives a household key or a plaintext barcode. It does verify that public keys are valid
points on the curve, that sizes are within bounds and that a client's clock is not implausibly far
ahead.

== Distribution of information

#dtable(
  columns: (1.3fr, auto, auto, 1.4fr),
  header: ("Datum", "Phone", "Server", "Why the server has it (or not)"),
  [Barcode payload, symbology, label, amount], [plain], [sealed], [The secret. Only phones holding K can open it.],
  [Kind, store, status, timestamps], [plain], [plain + sealed copy], [Plain for last-write-wins, dedupe, sync; phones trust only the sealed copy (@sec-sealed-meta).],
  [`payload_mac`], [—], [plain], [Blind index for dedupe: equal payloads ⇒ equal MACs, but not reversible without K.],
  [Household key K], [Keychain], [never], [Travels only inside wraps the server cannot open.],
  [Device private key], [Secure Enclave], [never], [Not even exportable from the phone.],
  [Device public key], [yes], [yes], [Needed to address wraps; validated on the curve.],
  [Store address and coordinates], [yes], [yes], [Global facts, not secret: printed on every bon.],
  [Username, passkey public key], [username], [yes], [Accounts. The username is not encrypted at rest (few known users).],
)

#note[The division between sealed and plaintext columns is the central design choice of the
backend. Everything the server needs in order to *order and deduplicate* is plaintext; everything
that is *valuable* is sealed; and anything the server could *tamper with* to the detriment of the
household is sealed as well, even where a plaintext copy also exists.]
