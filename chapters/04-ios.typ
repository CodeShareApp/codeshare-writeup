#import "../lib.typ": *

= The iOS app

The product is called *Code Share*, two words, in everything a user reads (home screen name,
share footer, this report). Identifiers keep the single word: the `ios/CodeShare/` sources, the
`CodeShare` scheme and test target, the App Group `group.dev.moroz.CodeShare` and the
`codeshare/v1/…` key-derivation labels, which cannot change without a migration (@sec-key-labels).

The app comprises about 6,800 lines of Swift in `ios/CodeShare/` (`Models`, `Services`, `Views`,
`Views/Components`, `Resources`) and roughly 180 XCTest cases. The Xcode project is a hand-written
`pbxproj` with file-system synchronised groups, so a new file in `ios/CodeShare/` requires no
project edit.

== Local-first storage: SQLite through GRDB <sec-grdb>

The initial plan specified SwiftData. It was replaced by SQLite through GRDB.swift before any
storage code was written, for four reasons:

+ *Portability.* SwiftData needs iOS 17; the scanner floor is iOS 16. GRDB runs on iOS 13.
+ *Readable queries.* The rules in this app are relational: "store address only if it has
  none yet", "push rows of this household or of none", "delete every row a household synced".
  Each is a single SQL statement (`INSERT … ON CONFLICT DO UPDATE SET … CASE WHEN`).
+ *Sharing a file.* The widget and the share extension open the same database from other
  processes. A plain SQLite file in WAL mode in an App Group container is the most predictable
  means of doing so.
+ *The server mirror.* The phone's tables deliberately mirror the server's (`codes`, `stores`),
  so that sync is a column-to-column mapping, not an object-graph translation.

=== Migrations

Migrations are registered in `AppDatabase.migrator` as plain SQL and run once each, in order.
The rule is absolute: *a migration that has shipped to a phone is never edited; a new one is
added instead.*

#dtable(
  columns: (auto, 1fr),
  header: ("Migration", "What it does, and why"),
  [`v1`], [`stores` (filiaal number PK, address) and `codes` (UUID text PK, kind, payload, symbology, label, amount, timestamps, soft delete). Unique live payload.],
  [`v2-store-coordinates`], [Nullable `lat`/`lng` for on-device geocoding.],
  [`v3-unique-payload`], [Payload unique across *all* rows, deleted included: rescanning a deleted bon revives the old row (same id) instead of inserting a second id. Cleans up older duplicates first.],
  [`v4-geocode-backoff`], [Attempts and last attempt per store, so failed geocodes back off (1 h doubling to a week). Kept in the database because the app is relaunched frequently.],
  [`v5-code-status`], [`status` = `unused` | `used` | `rejected` (the till refused it), backfilled from `used_at`.],
  [`v6-sync`], [Sync bookkeeping: `dirty`, `household_id`, `key_version`, `server_updated_at`, `stores.server_synced`, `sync_state.cursor`. `dirty` defaults to 1, so codes saved before sign-in are pushed once a household exists.],
)

During development the Simulator erases the database on a schema change
(`eraseDatabaseOnSchemaChange`). The flag was initially guarded by `#if DEBUG`, and review
identified the hazard: *phones also run Debug builds* (a free team sideloads Debug), so an edited
migration would have erased real vouchers. It is now `#if targetEnvironment(simulator)`.

=== Identifiers

Ids are created on the phone, offline, as *UUIDv7*: 48 bits of Unix milliseconds followed by
random bits. Swift's `UUID()` produces version 4, so a small helper is provided:

```swift
static func v7(at date: Date = Date()) -> UUID {
    var g = SystemRandomNumberGenerator()
    var bytes = (0..<16).map { _ in
        UInt8.random(in: .min ... .max, using: &g) }
    let ms = UInt64(max(0,
        (date.timeIntervalSince1970 * 1000).rounded(.down)))
    for i in 0..<6 {   // big-endian: byte 0 holds the most significant bits
        bytes[i] = UInt8(truncatingIfNeeded: ms >> (8 * (5 - i)))
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x70   // version 7
    bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC variant 10xx
    return UUID(uuid: (bytes[0], bytes[1], /* … */ bytes[15]))
}
```

Time-ordered ids keep PostgreSQL's primary-key index append-only, and the server checks the
version and variant bits of every id it accepts. On the phone they are stored as lowercase text.

=== One payload, one id

A barcode is the identity of a voucher. `AppDatabase.save` therefore *revives* a soft-deleted row
with the same payload (its id, `deleted_at` cleared) rather than adding a row, and throws
`StorageError.duplicate` for a live one. The server enforces the same rule with a unique
`(household_id, payload_mac)`; Chapter 7 describes how a phone adopts the server's id when the two
differ.

== The scanning pipeline

#fig(
  canvas(38mm, {
    let y = 4mm
    node(0mm, y, 27mm, 14mm)[`DataScanner-` \ `ViewController`]
    node(0mm, y + 19mm, 27mm, 12mm, stroke: c.muted)[Photo / share \ (Vision)]
    node(36mm, y + 7mm, 26mm, 14mm)[`ScanAccumulator` \ per frame]
    node(71mm, y + 7mm, 22mm, 14mm)[`BonParser` \ (pure)]
    node(102mm, y + 7mm, 34mm, 14mm)[`CodeDraft` → form \ → `AppDatabase.save`]
    arrow((27mm, y + 7mm), (36mm, y + 12mm))
    arrow((27mm, y + 25mm), (36mm, y + 17mm))
    arrow((62mm, y + 14mm), (71mm, y + 14mm))
    arrow((93mm, y + 14mm), (102mm, y + 14mm))
    label(36mm, y + 23mm, w: 60mm)[barcodes counted across frames; \ text parsed frame by frame, fields merged]
  }),
  [From camera or picture to a saved code. Every stage after the scanner is a pure value or
  function and is tested without a camera.],
) <fig-scan>

`DataScannerViewController` recognises barcodes and text in one pass and reports items as the
camera moves. Two review findings determined the design of `ScanAccumulator`:

- *Parse one frame at a time.* VisionKit's text positions are relative to the current picture.
  The first version kept text from earlier frames and sorted it together with the current one,
  interleaving lines from different camera positions. Each frame is now sorted top-to-bottom and
  parsed on its own, and the *fields* are merged (newer reading wins, a missed field keeps its
  earlier value). Barcodes, in contrast, are counted across all frames: a misread is rarely seen
  twice, so the most-seen valid EAN-13 wins.
- *Compile regexes once.* The parser runs on every camera update; each match used to compile a
  fresh `NSRegularExpression`. `RegexCache` removes this cost.

The parser is a pure function from lines to a `ParsedBon`. The bon's dot-matrix font causes OCR
to insert spaces inside words and confuse `i`/`l`/`1` and `O`/`0`, so the patterns are tolerant:

```swift
/// `Filiaal: 4520`, `Filiaal#4520`,
/// `F i l i a a l : 4 5 2 0`, `Fi1iaa1 4520`.
static func filiaalNumber(in line: String) -> Int? {
    let compact = line.filter { !$0.isWhitespace }
    guard let m = compact.firstMatch(
        of: #"(?i)f[il1|!]{3}aa[il1|!][^0-9]{0,3}([0-9]{3,5})(?![0-9])"#)
    else { return nil }
    return Int(m[1])
}
```

The amount has four sources, in order of trust: a `€ 0.55` anywhere (also `€0,55`); a line that is
only an amount after something OCR made of the euro sign (`E 0.55`, `C 0.55`); the first bare
amount after "Emballagebon"; and the sum of the line items. Timestamps are parsed in
`Europe/Amsterdam` with Dutch month abbreviations (and `O`→`0` repaired). The printed digits
under the bars are accepted as a barcode only if the EAN-13 check digit is correct.

#lesson[`DataScannerViewController.isAvailable` is `false` until camera access is granted. The
first build checked it before requesting access, so a fresh install proceeded directly to manual
entry and never displayed the permission prompt. Access must be requested before availability is
evaluated.]

== EAN-13 rendering <sec-ean13>

CoreImage can generate QR, Code 128, PDF417 and Aztec, but not EAN-13, which is the symbology
used by the vouchers and the Bonuskaart. `EAN13.swift` implements it from the GS1 tables: 95 modules =
start guard `101`, six left digits × 7 modules, centre guard `01010`, six right digits × 7, end
guard `101`. The first digit is not drawn; it selects, per left digit, the L or G coding
(`parityPatterns`). The check digit weights the first twelve digits 1, 3, 1, 3, …:

```swift
static func checkDigit(for first12: String) -> Int? {
    let digits = first12.compactMap(\.wholeNumberValue)
    guard digits.count == 12, first12.count == 12 else { return nil }
    let sum = digits.enumerated().reduce(0) { sum, pair in
        sum + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
    }
    return (10 - sum % 10) % 10
}
```

Rendering is as important as encoding. `BarcodeRenderer` makes a bitmap with *one pixel per
module* (a 1-pixel-tall row for EAN-13, plus the 11- and 7-module quiet zones), and `BarcodeView`
scales it by a *whole number* of screen pixels with interpolation off. Every bar retains sharp edges
and equal widths, as a till scanner requires. Barcodes are always black on white, including in
dark mode.

== Photo import and Simulator-specific behaviour

"From photo" (the system photo picker, no library permission) and, later, the share extension feed
pictures through `PhotoCodeReader`: Vision's `VNDetectBarcodesRequest` and
`VNRecognizeTextRequest` with `usesLanguageCorrection = false` (bons consist of codes and
numbers, and language correction corrupts amounts). The output has the same shape as the live scanner's, so it
reuses `ScanAccumulator`, `BonParser` and the confirmation form unchanged. Two Simulator-only
workarounds are placed behind `#if targetEnvironment(simulator)`: Vision must run CPU-only (no Neural
Engine: "Could not create inference context"), and the barcode request must use *revision 1*,
because the current model finds nothing on the Simulator's CPU path.

#lesson(title: "Found in use (6 October 2026)")[A photograph of a fresh Albert Heijn bon did not
import from the gallery, while the live scanner read the same bon. An independent decoder
(zxing-cpp) also failed on the photograph, at full and at reduced resolution, and succeeded once
the strip left of the paper's edge was painted white: the Tomra prints the bars about three to four
modules from the edge of the paper, where EAN-13 asks for eleven, and in a hand-held photograph
the space beyond the edge is a dark hand or floor. A strict still-image decoder sees no quiet zone;
the live scanner gets dozens of frames, some of them lucky. The remedy is a retry ladder in
`PhotoCodeReader`: the picture as it is; then the paper found by `VNDetectDocumentSegmentationRequest`,
perspective-corrected and placed on a white canvas with a wide margin; at full resolution, never
below about three pixels per module. If all fail, the printed digits under the bars, read by OCR and
accepted only with a valid check digit, supply the payload, as the parser already allows. A test
fixture renders a made-up `980…` EAN-13 three modules from a dark border.]

== Brightness <sec-brightness>

A code screen raises the display to full brightness and restores the previous level afterwards.
iOS does not restore the level automatically, and it retains an app-set brightness after the app
has terminated, so the saved level is kept in `UserDefaults` (restored at the next launch after a crash) and the boost follows
visibility, scene phase and whether a sheet covers the code.

The first test on a real phone revealed a severe defect: leaving the barcode screen set the
brightness to *zero*. The level saved on boost had been read as 0. The correction clamps the value
in both directions and reads the level only while the app is actually active:

```swift
nonisolated static let minimumRestore = 0.2

static func boost(defaults: UserDefaults = .standard) {
    guard defaults.object(forKey: savedKey) == nil, let screen,
          UIApplication.shared.applicationState == .active else { return }
    defaults.set(levelToSave(Double(screen.brightness)), forKey: savedKey)
    screen.brightness = 1
}

nonisolated static func levelToSave(_ reading: Double) -> Double {
    guard reading.isFinite else { return minimumRestore }
    return min(max(reading, minimumRestore), 1)
}
```

#lesson[Simulator tests could not have detected this defect, because the Simulator has no
brightness control. The asymmetry "an overly bright screen is the safer failure" is recorded in
the code comment.]

== Location and store presence

`LocationProvider` wraps CoreLocation (when-in-use, one fix per refresh) behind a `LocationSource`
protocol; `StoreProximity` is pure. Stores are sorted nearest first *within* tiers (stores with
unused vouchers, then used-only stores, then the unknown store). The "you are at Albert Heijn" card
requires a store within 100 m, a fix no older than 5 minutes and a horizontal accuracy of at most
65 m. Review tightened the accuracy from 200 m because Albert Heijn stores can be about 300 m
apart. Store coordinates are obtained first from MapKit on the phone and subsequently from the
server's PDOK result, which takes precedence.

== Localisation and appearance

Every string is in English (source), Dutch and Traditional Chinese (Taiwan forms), via String
Catalogs, including the camera and location permission texts in `InfoPlist.xcstrings`. Money and
dates use the locale's format; data (addresses, codes) is shown verbatim (`Text(verbatim:)`).
`xcodebuild` does not update catalogs, so new keys are added to the JSON manually and checked
against the build's `.stringsdata`. When parallel branches both added keys, merges were resolved
*semantically*, by merging the JSON key sets, not by editing conflict markers.

All colours, fonts, spacing and radii are defined in `Theme.swift`. The interim palette is
"Tickets" teal (`#0F766E` light accent, `#5EEAD4` dark) with full dark mode; the colours of this
document are derived from it. Review found that swipe-action labels were rendered white on light
teal in dark mode (contrast 1.5:1); they now use fixed dark teal and red in both appearances.

#fig(
  image("/images/ios-interim-look.png", width: 100%),
  [The interim appearance in English, Dutch and Traditional Chinese, light and dark (Simulator,
  fictitious data). A design pass with three mocked directions is pending.],
)

== Onboarding, local mode and sign-in

The flow mirrors holy-shit-ios's `OnboardingView` (Welcome → "Create an account" → username →
passkey, or "I already have an account" → passkey; then a household screen: create, join, later),
with one addition: *"Use without an account"*. In local mode the app makes no network calls;
nothing networked runs without a session. The decision of what to display at launch is a pure
function, which made the difficult case (an existing install with real vouchers and no account)
testable:

```swift
static func screen(hasAccount: Bool, localModeChosen: Bool,
                   hasLocalData: Bool) -> LaunchGate {
    hasAccount || localModeChosen || hasLocalData ? .app : .onboarding
}
```

Sign-in on a free team follows the holy-shit approach (to be replaced by native passkeys on the
paid team, @sec-paid-team): `ASWebAuthenticationSession` opens the server's
`/auth` page (WebAuthn runs in the browser, under `codeshare.shop`), which redirects to
`codeshare://auth?code=…`; the app exchanges the one-time code at `POST /api/auth/token` for a
bearer token kept in the Keychain. The session token never appears in a URL. Signing out returns to
local mode, never to Welcome.

== Widget and sharing (built, not merged) <sec-widget>

The `widget` workspace contains fifteen commits not yet in the main line:

- *App Group database.* The SQLite file moves to `group.dev.moroz.CodeShare/Database` on first
  launch (companions `-wal`/`-shm` first, main file last, so that an interrupted move completes at
  the next launch), with persistent WAL so the widget can open it read-only and GRDB's suspension handling
  against the `0xdead10cc` termination.
- *Widget.* Small: unused total, voucher count, the store worth most. Medium: the Bonuskaart
  barcode and the total. Both marked `.privacySensitive()` so the lock screen redacts them.
- *Share out.* `BonImageRenderer` draws a voucher as an emballagebon look-alike PNG (text only,
  no logo). A test renders a fictitious voucher and reads it back through `PhotoCodeReader` and
  `BonParser` to the same payload, store, amount and issue time, demonstrating that the picture is a valid
  import.
- *Share in.* A share extension takes up to ten pictures, decodes them to at most 2048 px (an
  extension has about 120 MB) and saves through the same `AppDatabase.save`.

Six review findings were addressed on this branch alone, all concerning the database move: a
companion file already moved is never deleted (a moved `-wal` can hold commits); a fresh empty
database is not started once the codes reside in the App Group but the build lacks the
entitlement; the old file is used in place if the move fails; the extension never runs migrations
(it could race the app's first migration); and saves occur off the main thread. The branch as a
whole depends on one fact that cannot be verified from the command line: whether a free team can
provision an App Group (@sec-signing).
