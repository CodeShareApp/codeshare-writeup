#import "../lib.typ": *

= A second chain: the REWE Pfandbon <sec-rewe>

This chapter is a *specification*, not a description of built code. It was written from one real
REWE deposit voucher (a _Pfandbon_), printed on 5 October 2026, which the app failed
to recognise: the scanner accepts only EAN-13, and the Pfandbon carries a Code 128 barcode. As in
@fig-bon, the sample's digits, store and voucher number are not reproduced; @fig-rewe uses
fictitious values with the same layout.

== Pfand in Germany

Germany's deposit, _Pfand_, distinguishes two kinds of container. _Einweg_ (single-use: cans and
most plastic bottles) carries a flat 25 cents. _Mehrweg_ (refillable: glass and some returnable
plastic) carries 8 or 15 cents. A reverse vending machine at a REWE supermarket prints one voucher
for a whole return, grouped by kind, which the till accepts as store credit.

== Anatomy of a Pfandbon

#let bonline(body, al: left, size: 7.6pt, weight: "regular") = align(al, text(font: mono-font, size: size, fill: c.ink, weight: weight, tracking: 0.06em, body))

#fig(
  block(width: 64mm, fill: c.paper, inset: (x: 6mm, y: 5mm), radius: 1pt, {
    set par(leading: 0.45em, spacing: 0.45em, justify: false)
    bonline(al: center, size: 11pt, weight: "bold")[REWE]
    v(1mm)
    bonline(al: center)[Beispielweg 12]
    bonline(al: center)[10115 Berlin]
    v(1mm)
    bonline(al: center)[Nr. 123456]
    v(1mm)
    bonline(al: center)[05.10.2026]
    bonline(al: center)[09:41]
    v(1mm)
    line(length: 100%, stroke: (paint: c.ink, thickness: 0.4pt, dash: "dashed"))
    bonline(al: center)[Anz. #h(0.8em) Bezeichnung #h(0.8em) Pfand]
    line(length: 100%, stroke: (paint: c.ink, thickness: 0.4pt, dash: "dashed"))
    bonline(al: center, size: 10pt, weight: "bold")[Mehrweg]
    bonline[6 Flasc.. à 0.15 #h(1fr) 0.90]
    bonline(al: center, size: 10pt, weight: "bold")[Einweg]
    bonline[5 Flasc.. à 0.25 #h(1fr) 1.25]
    line(length: 100%, stroke: (paint: c.ink, thickness: 0.4pt, dash: "dashed"))
    bonline(size: 10pt, weight: "bold")[Total:]
    bonline(al: right, size: 11pt, weight: "bold")[2.15 EUR]
    v(1mm)
    bonline(al: center)[Vielen Dank!]
    v(1mm)
    align(center, code128c("212345678901123456000215", module: 0.21mm, height: 9mm, ink: c.ink, bg: c.paper))
  }),
  [A Pfandbon as the parser should interpret it (fictitious store, number, amounts and barcode;
  the barcode is a real Code 128 rendering of the 24 digits, drawn by `code128c` in `lib.typ`,
  and decodes with an off-the-shelf reader).],
) <fig-rewe>

The barcode on the sample was decoded from a photograph with an independent reader (zxing-cpp):
*Code 128*, symbology identifier `]C0`, that is plain Code 128 without the FNC1 that would make
it GS1-128. Its bar widths take four values, which rules out Interleaved 2 of 5 (two widths), and
it ends in Code 128's stop pattern. The human-readable line under the bars is the full payload,
*24 digits*, and three groups of it can be explained from the printed text:

#dtable(
  columns: (auto, auto, 1fr),
  header: ("Digits", "Sample (fictitious)", "Meaning"),
  [1–12], [`212345678901`], [Not explained by anything printed. Hypothesis: market and machine identifiers, constant per machine. To be tested with a second bon from the same market and one from another.],
  [13–18], [`123456`], [Equal to the printed voucher number (`Nr.`).],
  [19–24], [`000215`], [The total in cents, zero-padded: 2.15 EUR.],
)

#note[This is the opposite of the emballagebon, where (as far as one sample shows) the amount is
*not* in the barcode. On a Pfandbon the amount can be read from the barcode alone, and the barcode
alone is what the till needs.]

Compared field by field with the emballagebon:

#dtable(
  columns: (auto, 1fr, 1fr),
  header: ("Field", "Albert Heijn emballagebon", "REWE Pfandbon"),
  [Barcode], [EAN-13, 13 digits, last is a check digit.], [Code 128 (subset C), 24 digits, no check digit in the digits; the symbol's own mod-103 check covers the scan.],
  [Store key], [Filiaal number, printed.], [None printed. Address only (and perhaps barcode digits 1–12).],
  [Address], [Street, then `NNNN AA` postcode and city.], [Street (house-number ranges such as `12-14`), then `NNNNN` postcode and city.],
  [Amount], [`€ 0.55` line; not in the barcode.], [`Total:` followed by `x.xx EUR` on the next line; also barcode digits 19–24.],
  [Line items], [`1x Blik 0.15`], [`<n> Flasc.. à <unit> <sum>` under `Mehrweg` / `Einweg` headings.],
  [Timestamp], [`18:42:10 01-OKT-2026`, Dutch months.], [`05.10.2026` and `09:41` on separate lines, no seconds.],
  [Voucher number], [In the transaction line.], [`Nr.`, also barcode digits 13–18.],
  [Expiry], [None printed.], [None printed.],
)

== What has to change

=== Scanning

- *Symbologies.* `DataScannerViewController` and `VNDetectBarcodesRequest` are configured for
  EAN-13 only, which is why the sample was not recognised. Add `.code128` to both. The
  `ScanAccumulator` rule "the most-seen *valid EAN-13* wins" becomes "the most-seen valid payload
  *per symbology* wins", with validity per symbology: EAN-13 check digit, or for a Pfandbon
  24 digits whose last six parse as the amount.
- *Printed digits.* The 24 printed digits carry no check digit, so an OCR reading of them cannot be
  validated on its own. They are accepted as the payload only when no barcode was decoded *and*
  digits 13–18 equal the parsed `Nr.` *and* digits 19–24 equal the parsed total. Otherwise the
  confirmation form asks for another scan rather than store an unchecked payload.
- *Cross-check.* A Pfandbon has three amount sources that must agree: barcode digits 19–24, the
  `Total:` line and the sum of line items. A disagreement is shown on the confirmation form, with
  the barcode's value preselected (the till will use it regardless).

=== Parsing

`BonParser` gains a chain detection step and a second set of rules; the detection is the first
non-empty line (`REWE` versus `Albert Heijn`, tolerant of the same OCR confusions), and failing that
the barcode symbology. The REWE rules:

- *Address:* the street is the line above a line matching `^\d{5}\s+\S` (German postcode, five
  digits, then the city). House numbers may be ranges (`12-14`) or carry a letter (`12a`).
- *Voucher number:* `Nr.` followed by digits; the same `O`→`0` repair as the timestamp.
- *Amount:* the first amount after `Total:`, on the same line or the next, with an optional
  `EUR`. The decimal separator on the sample is a point; a comma is accepted as well.
- *Line items:* `^(\d+)\s+\S+\.*\s+à\s+(\d+[.,]\d{2})\s+(\d+[.,]\d{2})$`, where count × unit must
  equal the line sum. `à` is often read by OCR as `a` or `á`.
- *Timestamp:* `dd.MM.yyyy` and `HH:mm` on separate lines, parsed in `Europe/Berlin` (today the
  same offset as `Europe/Amsterdam`, but the zone is a property of the chain's country, not of
  the parser).

=== Rendering

CoreImage's `CICode128BarcodeGenerator` produces Code 128 (it has no EAN-13 generator, @sec-ean13),
but it chooses the code set itself. The same rules as for EAN-13 apply to its output: one pixel per
module, scaled by a whole number of screen pixels with interpolation off, black on white. A unit
test renders the fictitious payload above and decodes it with Vision, which must return the same
24 digits. If the generator's output fails that test, a subset C encoder is about forty lines (the
one in `lib.typ` is twenty) and keeps the app independent of the generator's choices.

=== Data model and sync

The local and server schemas already carry a `symbology` column, and the sealed payload already
includes it (@sec-sealed-meta), so codes need no migration: a Pfandbon is a code with
`symbology = "code128"`. Stores do:

- *Store key.* Stores are keyed by filiaal number, and a Pfandbon prints none. The key becomes
  `(chain, key)`, as already anticipated for Jumbo (@sec-rewe-open). Until a second bon settles
  whether barcode digits 1–12 identify the market, a REWE store's key is derived from the
  normalised address (postcode, street, house number). The server's immutable-address rule
  (first bon prevails) then holds trivially, since the address *is* the key.
- *Geocoding.* The server accepts a new store only if PDOK geocodes it *inside the Netherlands*.
  A Berlin store would be refused with 400. German stores need a second geocoder behind the same
  rules (restricted to the postcode, coordinates validated inside a bounding box, an unreachable
  geocoder saves the store unverified). OpenStreetMap's Nominatim with `countrycodes=de` and
  `postalcode` fits the volume (its usage policy allows one request per second); the squatting
  limit of ten new stores per user per day applies unchanged.
- *Display.* "Albert Heijn · city" becomes "chain · city" from the existing `Chain` enum; grouping,
  nearest-store sorting and the at-store card work per store and need no change. The Bonuskaart
  remains Albert Heijn's.

== Open questions <sec-rewe-open>

- *Digits 1–12.* Do they identify the market, the machine, or the date? One sample cannot say.
  A second bon from the same machine, one from another machine in the same market, and one from
  another market answer it, and decide the store key.
- *Redemption rule.* The app assumes, as for Albert Heijn, that a Pfandbon is redeemable only at
  the issuing market. This is to be confirmed at a till, as the screen-scan was for Albert Heijn.
- *Screen scanning.* Whether REWE tills read a Code 128 from a phone screen has not been tested.
  Code 128 at 24 digits is wider than EAN-13 (167 modules against 95, before quiet zones), so the
  code screen should prefer landscape for it.
- *Other chains.* Lidl, Aldi and Edeka print their own Pfandbons. The per-chain parser and the
  `(chain, key)` store key are intended to make each a set of rules rather than a redesign.

#lesson[The scanner was restricted to the one symbology of the one sample. That kept the
first version small and its validation strict, but it encoded "a voucher is an EAN-13" as an
assumption no test could reveal; the first bon from a second chain did. Reading the failing
artefact with an independent decoder settled the symbology in minutes, before any code was
changed.]
