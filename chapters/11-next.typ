#import "../lib.typ": *

= Status and next steps

== Current state (3 October 2026)

#dtable(
  columns: (1.45fr, 0.75fr, 1.6fr),
  header: ("Piece", "State", "Notes"),
  [Local app (scan, parse, store, EAN-13, used/rejected, geocoding, location sort)], [built], [Running on the developer's phone (where the brightness defect was found).],
  [Onboarding, local mode, passkey sign-in], [built], [Passkeys on a real phone and the join between two real phones remain to be tested (covered in the Simulator by `LiveServerTests`).],
  [Households, E2EE sync, Secure Enclave keys], [built, main line], [Reviewed; tested against a local DEV server.],
  [Backend (Curve25519 era)], [deployed], [`codeshare.shop`, telemetry on, backups configured.],
  [Backend (glowie-curve keys)], [reviewed, not deployed], [Awaits confirmation of the new build on the phone, then wipe + deploy (@sec-wipe).],
  [Widget, share in], [built, not merged], [Needs the App Group check in Xcode (@sec-signing).],
  [Share out (bon picture)], [built, not merged], [On the widget branch; needs no App Group.],
  [Domain split (`api.` + landing page)], [in progress], [App base URL switched in the main line; landing page and server side not merged or deployed. RP ID unchanged.],
  [Design pass], [waiting], [Three directions mocked; one is to be selected by the household.],
)

== Open items

- *Store visit ("redeem mode").* Planned: at a store, one full-screen card stack at maximum
  brightness, showing the Bonuskaart first and then each redeemable voucher; swipe up = used,
  left = rejected, right = skip, with undo and a "€ x redeemed" summary. At present the at-store
  card's Redeem button opens the first unused voucher.
- *Key rotation UI and member removal UI.* The server supports leaving, removing a member, deleting a
  device and rotating; phones handle receiving a rotation. No control in the app initiates either yet,
  and a removal is safe only once it is followed by a rotation.
- *Recovery code.* An optional printed or password-manager code that also wraps K, so that loss of
  every phone in the household does not entail loss of the codes.
- *Jumbo.* Stores would need a chain column and a `(chain, number)` key; the app already has a
  `Chain` enum and displays "Albert Heijn · city" throughout.
- *Paging* for `GET /api/sync` (a full resync returns everything in one response).
- *PDOK street-level validation.* At present an address passes if PDOK finds it within the postcode; a
  stricter check would compare the house number.
- *Verification of the amount rule* against a second bon (whether the amount is indeed absent from
  the barcode).
- *Expiry rules* per household, and the Apple Watch app (whether an Albert Heijn scanner reads an
  EAN-13 from a watch face remains to be tested).

== Suggested reading order

For study of the system through its code, the following order follows the data:

+ `BonParser.swift` and `ScanAccumulator.swift`: pure, small, with tests that serve as a
  specification.
+ `EAN13.swift` and `BarcodeRenderer.swift`: the complete symbology in about a hundred lines.
+ `AppDatabase.swift` (migrations) and `AppDatabase+Sync.swift`: the local model and its rules.
+ `HouseholdCrypto.swift`: the doc comment at the top is the cryptographic spec; then
  `HouseholdCryptoTests.swift` for the vectors.
+ `HouseholdService.swift`: joining, self-wraps, generations.
+ `SyncEngine.swift`: push, pull, 409, 422, merge.
+ Backend: `internal/repository/sync.go` (the extended comment on the cursor), `internal/repository/households.go`
  (joins, rotation), `internal/service/stores.go` (squatting defences).
