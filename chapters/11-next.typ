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
  [Share out (bon picture)], [built, not merged], [On the widget branch; needs no App Group. Albert Heijn template only; per-chain templates specified (@sec-share-templates).],
  [Domain split (`api.` + landing page)], [in progress], [App base URL switched in the main line; landing page and server side not merged or deployed. RP ID unchanged.],
  [German Pfandbons (REWE, EDEKA; Code 128)], [specified], [Two real bons; the REWE one not recognised by the scanner. Specification in @sec-rewe.],
  [Biesieklette parking tags (QR)], [specified], [New `parking` kind, location sealed; @sec-parking.],
  [Generic codes, boarding pass import], [specified], [Any code saved without questions; BCBP parsing, PDF and `.pkpass` import; @sec-any-code.],
  [Sealed stores and code metadata], [specified], [Store rows per household, sealed; plaintext kind, status and timestamps dropped; ships with the wipe (@sec-sealed-stores).],
  [Name "Code Share" (two words)], [decided], [Display name and share footer to change; identifiers stay `CodeShare`.],
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
- *Jumbo and REWE.* Stores would need a chain column and a `(chain, key)` key; the app already
  has a `Chain` enum and displays "Albert Heijn · city" throughout. For German chains, whose
  Pfandbons are Code 128 without a printed store number, the specification is @sec-rewe.
- *Paging* for `GET /api/sync` (a full resync returns everything in one response).
- *PDOK street-level validation.* At present an address passes if PDOK finds it within the postcode; a
  stricter check would compare the house number. Moot once stores are sealed (@sec-sealed-stores)
  and the server validates nothing.
- *Verification of the amount rule* (done): a second Albert Heijn bon, of 2 October 2026, also
  carries no amount in its barcode. Its EAN-13 begins with `980`, GS1's refund-receipt prefix, as
  the EDEKA Tomra bon does (@sec-rewe); the fictitious sample of @fig-bon begins with `2` and
  should follow suit when the figure is next redrawn.
- *Expiry rules* per household, and the Apple Watch app (whether an Albert Heijn scanner reads an
  EAN-13 from a watch face remains to be tested; @sec-qr-test may make the question moot).
- *QR codes at the till* (@sec-qr-test).

== Experiment: QR codes at the till <sec-qr-test>

The app shows every code in the symbology printed on the paper. The till scanners are 2D imagers
(Zebra handhelds at the staffed tills), and such imagers decode QR as readily as EAN-13. If the
till accepts *the same digits in a QR code*, the code screen could show QR instead of, or next to,
the linear barcode. That would bring three gains:

- *Robustness on screens.* QR has Reed–Solomon error correction and no fine module widths to
  preserve, so a dimmed screen, a cracked protector or moiré matters less than for EAN-13.
- *Size.* The digits fit QR's numeric mode: 13 digits (EAN-13) or even 32 (the EDEKA Leergutbon,
  @sec-rewe) fit a version-1 symbol, 21 × 21 modules, at error-correction level M. That is small
  enough for a watch face, where a 95-module EAN-13 is not, and avoids landscape for the wide
  Code 128s.
- *Generation.* CoreImage's `CIQRCodeGenerator` produces it, with the same one-pixel-per-module
  output as the other generators.

That the scanner *can* decode QR does not settle it. Three things lie between the scanner and the
credit:

+ *The scanner's configuration.* Symbologies are enabled per scanner, and a retailer may have
  enabled only the linear ones it needs.
+ *The symbology identifier.* A scanner can prefix each read with its AIM identifier (`]E0` for
  EAN-13, `]Q1` for QR). If it does, the POS software may route or reject by it, and the same
  13 digits arriving as QR may not be treated as a voucher.
+ *The payload.* The QR must contain exactly the digits, in numeric mode, with no newline, prefix or
  URL. A GS1 Digital Link (`https://…/01/…`) would be parsed differently, if at all.

The test therefore climbs from harmless to consequential, stopping at the first failure:

#dtable(
  columns: (auto, 1fr, 1fr),
  header: ("Step", "Show at the till", "What a pass shows"),
  [1], [The Bonuskaart as EAN-13, from the app (baseline).], [The till and the screen work together at all.],
  [2], [The Bonuskaart as QR (13 digits, numeric mode, level M, 4-module quiet zone).], [The scanner has QR enabled and the POS accepts the digits from a QR. Bonus prices appear.],
  [3], [A low-value emballagebon as QR, the paper in the other hand.], [Vouchers are credited from a QR; the screen may switch to QR for Albert Heijn.],
  [4], [Step 2 at a self-checkout.], [The same for the self-checkout scanners, which may be a different make.],
)

For each step, the result is one of: accepted; read but refused ("onbekend artikel" or an error,
meaning the scanner decoded it and the POS declined, which points at causes 2 or 3); or no reaction
(the scanner did not decode it, cause 1). Step 1 must pass before any other result means
anything. The outcome is recorded per chain and per till type. The code screen then
picks the symbology from that record, defaulting to the one printed on the paper. Until the test
is done, nothing changes in the app: QR display is a candidate feature, not a plan.

#note[A refusal at step 3 after a pass at step 2 is the interesting case. It would mean the POS
distinguishes vouchers by symbology, not only by digits, and that a voucher must be shown as
printed.]

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
