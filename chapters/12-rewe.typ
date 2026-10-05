#import "../lib.typ": *

= German Pfandbons: REWE and EDEKA <sec-rewe>

This chapter is a *specification*, not a description of built code. It was written from two real
German deposit vouchers (_Pfandbons_): one from REWE, printed on 5 October 2026, which the app
failed to recognise, and one from EDEKA, printed by a Tomra machine in 2023, from a photograph
already published on the web. The scanner accepts only EAN-13, and both carry a Code 128 barcode.
Unlike the Albert Heijn sample (@fig-bon), the REWE bon is redeemed and the EDEKA bon's digits are
public already, so @fig-rewe and @fig-edeka reproduce their real values, barcodes included; only
the EDEKA merchant's name, a person's surname, is left out.

== Pfand in Germany

Germany's deposit, _Pfand_, distinguishes two kinds of container. _Einweg_ (single-use: cans and
most plastic bottles) carries a flat 25 cents. _Mehrweg_ (refillable: glass and some returnable
plastic) carries 8 or 15 cents. A reverse vending machine prints one voucher for a whole return,
which the till accepts as store credit; REWE calls it a Pfandbon, EDEKA a _Leergutbon_.

The specification takes the same redemption rule as for Albert Heijn: *a Pfandbon is redeemable
only at the market that printed it.* This is a design assumption, not a confirmed fact; if a
chain turns out to accept bons chain-wide, the rule only widens (any REWE becomes "here" for the at-store
card), and nothing stored has to change.

Unlike the emballagebon, a Pfandbon has a *legal* expiry even though none is printed. It is
generally treated as a small bearer instrument (_kleines Inhaberpapier_, § 807 BGB), and the claim
it represents is subject to the regular limitation period of three years (§ 195 BGB), which runs
from the end of the year of issue (§ 199 BGB). A bon printed on 5 October 2026 can therefore be
refused from 1 January 2030; the EDEKA sample from July 2023 remains good until 31 December 2026.
A market may also refuse a bon that is illegible, or that is not the original paper, since the
paper is the instrument. These points come from general sources#footnote[For example
#link("https://www.refrago.de/pfandbon-fuer-flaschenpfand-wie-lange-ist-ein-pfandbon-gueltig-und-wann-darf-ein-supermarkt-die-annahme-eines-pfandbons-verweigern/")[refrago.de: "Pfandbon für Flaschenpfand: Wie lange ist ein Pfandbon gültig"].
Not legal advice.] and are taken as design inputs, not as verified law.

== Anatomy of a REWE Pfandbon

#let bonline(body, al: left, size: 7.6pt, weight: "regular") = align(al, text(font: mono-font, size: size, fill: c.ink, weight: weight, tracking: 0.06em, body))

#fig(
  block(width: 64mm, fill: c.paper, inset: (x: 6mm, y: 5mm), radius: 1pt, {
    set par(leading: 0.45em, spacing: 0.45em, justify: false)
    bonline(al: center, size: 11pt, weight: "bold")[REWE]
    v(1mm)
    bonline(al: center)[Hauptstr. 140-144]
    bonline(al: center)[10827 Berlin]
    v(1mm)
    bonline(al: center)[Nr. 741474]
    v(1mm)
    bonline(al: center)[05.10.2026]
    bonline(al: center)[13:25]
    v(1mm)
    line(length: 100%, stroke: (paint: c.ink, thickness: 0.4pt, dash: "dashed"))
    bonline(al: center)[Anz. #h(0.8em) Bezeichnung #h(0.8em) Pfand]
    line(length: 100%, stroke: (paint: c.ink, thickness: 0.4pt, dash: "dashed"))
    bonline(al: center, size: 10pt, weight: "bold")[Mehrweg]
    bonline[10 Flasc.. à 0.15 #h(1fr) 1.50]
    bonline(al: center, size: 10pt, weight: "bold")[Einweg]
    bonline[7 Flasc.. à 0.25 #h(1fr) 1.75]
    line(length: 100%, stroke: (paint: c.ink, thickness: 0.4pt, dash: "dashed"))
    bonline(size: 10pt, weight: "bold")[Total:]
    bonline(al: right, size: 11pt, weight: "bold")[3.25 EUR]
    v(1mm)
    bonline(al: center)[Vielen Dank!]
    v(1mm)
    align(center, code128c("226419311461741474000325", module: 0.21mm, height: 9mm, ink: c.ink, bg: c.paper))
  }),
  [The REWE Pfandbon sample, redrawn (real values, redeemed; the barcode is a Code 128 rendering
  of its 24 digits, drawn by `code128c` in `lib.typ`,
  and decodes with an off-the-shelf reader).],
) <fig-rewe>

The barcode on the sample was decoded from a photograph with an independent reader (zxing-cpp):
*Code 128*, symbology identifier `]C0`, that is plain Code 128 without the FNC1 that would make
it GS1-128. Its bar widths take four values, which rules out Interleaved 2 of 5 (two widths), and
it ends in Code 128's stop pattern. The human-readable line under the bars is the full payload,
*24 digits*, and three groups of it can be explained from the printed text:

#dtable(
  columns: (auto, auto, 1fr),
  header: ("Digits", "Sample", "Meaning"),
  [1–12], [`226419311461`], [Not explained by anything printed. Hypothesis: market and machine identifiers, constant per machine. To be tested with a second bon from the same market and one from another.],
  [13–18], [`741474`], [Equal to the printed voucher number (`Nr.`).],
  [19–24], [`000325`], [The total in cents, zero-padded: 3.25 EUR.],
)

#note[This is the opposite of the emballagebon, where (as far as one sample shows) the amount is
*not* in the barcode. On a REWE Pfandbon the amount can be read from the barcode alone, and the
barcode alone is what the till needs.]

== Anatomy of an EDEKA Leergutbon

#fig(
  block(width: 64mm, fill: c.paper, inset: (x: 6mm, y: 5mm), radius: 1pt, {
    set par(leading: 0.45em, spacing: 0.45em, justify: false)
    bonline(al: center, size: 11pt, weight: "bold")[EDEKA #h(0.6em) _(merchant)_]
    v(1mm)
    bonline(al: center)[Harleshäuserstr. 64]
    bonline(al: center)[34130 Kassel]
    bonline(al: center, size: 10pt, weight: "bold")[LEERGUTBON]
    bonline(al: right, size: 6.5pt)[Bon 076]
    block(width: 100%, fill: c.ink, inset: (x: 2mm, y: 1mm),
      align(right, text(font: mono-font, size: 11pt, weight: "bold", fill: c.paper)[€13.47]))
    align(center, code128c("98062710076218905500797000000007", module: 0.2mm, height: 9mm, ink: c.ink, bg: c.paper))
    bonline[Bepfandet]
    bonline[Kisten/Flaschen #h(1fr) 50]
    bonline(al: right)[2/7]
    line(length: 100%, stroke: 0.4pt + c.ink)
    bonline(al: center)[Tomra 9]
    bonline(al: center)[606657-90360001-69744-00]
    bonline(al: center)[09:52:49 08-JUL-2023]
  }),
  [The EDEKA Leergutbon sample, printed by a Tomra machine in 2023, redrawn (real values except the
  merchant's name; the barcode is a Code 128 rendering of its 32 digits).],
) <fig-edeka>

The barcode on this sample also decodes as plain Code 128 (`]C0`), but it has *32 digits* and a
different structure:

#dtable(
  columns: (auto, auto, 1fr),
  header: ("Digits", "Sample", "Meaning"),
  [1–3], [`980`], [GS1's prefix for refund receipts.],
  [4–8], [`62710`], [Not explained by anything printed.],
  [9–11], [`076`], [Equal to the printed `Bon` counter (three digits).],
  [12–31], [`21890550079700000000`], [Not explained by anything printed: neither the amount (`1347`), the date, nor the transaction line is among them.],
  [32], [`7`], [A GS1 mod-10 check digit over digits 1–31 (weights 3, 1, 3, … from the right), as in EAN-13. It verified on the sample; one sample cannot exclude coincidence (one in ten).],
)

Two observations matter more than the digits. First, the amount is absent from the barcode, as on
the Albert Heijn bon and unlike the REWE one. Second, the lower half of the bon is *the same Tomra
template* as the emballagebon (@fig-bon): a `Tomra 9` line, a transaction line of the form
`NNNNNN-NNNNNNNN-NNNNN-NN`, and a timestamp `HH:mm:ss dd-MMM-yyyy` with upper-case month
abbreviations. The layout of a voucher follows the *machine* that prints it as much as the chain
that issues it. The REWE sample prints no machine name and a different layout, so its vendor is
unknown.

Compared field by field:

#dtable(
  columns: (auto, 1fr, 1fr, 1fr),
  header: ("Field", "Albert Heijn emballagebon", "REWE Pfandbon", "EDEKA Leergutbon (Tomra)"),
  [Barcode], [EAN-13, 13 digits, check digit.], [Code 128, 24 digits, no check digit.], [Code 128, 32 digits, prefix `980`, GS1 check digit.],
  [Store key], [Filiaal number, printed.], [None printed; address (perhaps digits 1–12).], [None printed; merchant and address.],
  [Redeemable at], [Issuing store only.], [Issuing market only (assumed).], [Issuing market only (assumed).],
  [Address], [Street, then `NNNN AA` and city.], [Street (ranges such as `140-144`), then `NNNNN` and city.], [Street, then `NNNNN` and city.],
  [Amount], [`€ 0.55`; not in the barcode.], [`Total:` then `x.xx EUR`; also digits 19–24.], [`€x.xx`, printed white on black; not in the barcode.],
  [Line items], [`1x Blik 0.15`], [`<n> Flasc.. à <unit> <sum>` under `Mehrweg` / `Einweg`.], [Counts only (`Kisten/Flaschen 50`, `2/7`), no amounts.],
  [Timestamp], [Tomra: `18:42:10 01-OKT-2026`, Dutch months.], [`05.10.2026` and `13:25`, no seconds.], [Tomra: `09:52:49 08-JUL-2023`, German months.],
  [Voucher number], [In the transaction line.], [`Nr.`; also digits 13–18.], [`Bon`; also digits 9–11.],
  [Expiry], [None printed.], [None printed; three years from the end of the issue year (§§ 195, 199 BGB).], [As REWE.],
)

== What has to change

=== Scanning

- *Symbologies.* `DataScannerViewController` and `VNDetectBarcodesRequest` are configured for
  EAN-13 only, which is why the REWE sample was not recognised. Add `.code128` to both. The
  `ScanAccumulator` rule "the most-seen *valid EAN-13* wins" becomes "the most-seen valid payload
  *per format* wins", where a format is a symbology plus a payload shape: EAN-13 with its check
  digit; REWE, 24 digits whose last six parse as an amount; Tomra DE, 32 digits beginning `980`
  with a valid GS1 check digit. A Code 128 payload of any other shape is kept as an unknown
  format, saved only after the user confirms it, so a new chain degrades to manual entry of the
  store and amount rather than to "not recognised".
- *Printed digits.* The REWE digits carry no check digit, so an OCR reading of them cannot be
  validated on its own. They are accepted as the payload only when no barcode was decoded *and*
  digits 13–18 equal the parsed `Nr.` *and* digits 19–24 equal the parsed total. The Tomra digits
  are validated by their check digit and the `Bon` counter, as the EAN-13 digits are. Otherwise the
  confirmation form asks for another scan rather than store an unchecked payload.
- *Cross-check.* A REWE Pfandbon has three amount sources that must agree: barcode digits 19–24,
  the `Total:` line and the sum of line items. A disagreement is shown on the confirmation form,
  with the barcode's value preselected (the till will use it regardless). A Tomra Leergutbon has
  one source, the printed amount, and no line-item sum to fall back on.

=== Parsing

`BonParser` is split along the two axes the samples show. The *template* (which lines exist and
where) is detected from the barcode format and, failing that, from the text: a `Tomra` line with
the transaction line below it, or a `Total:` line with `à` item lines. The *chain* (and with it the
country, time zone and month names) is detected from the header: `Albert Heijn`, `REWE`, `EDEKA`,
tolerant of the same OCR confusions. The existing Albert Heijn rules become "Tomra template,
Dutch". The REWE rules:

- *Address:* the street is the line above a line matching `^\d{5}\s+\S` (German postcode, five
  digits, then the city). House numbers may be ranges (`140-144`) or carry a letter (`12a`).
- *Voucher number:* `Nr.` followed by digits; the same `O`→`0` repair as the timestamp.
- *Amount:* the first amount after `Total:`, on the same line or the next, with an optional
  `EUR`. The decimal separator on the sample is a point; a comma is accepted as well.
- *Line items:* `^(\d+)\s+\S+\.*\s+à\s+(\d+[.,]\d{2})\s+(\d+[.,]\d{2})$`, where count × unit must
  equal the line sum. `à` is often read by OCR as `a` or `á`.
- *Timestamp:* `dd.MM.yyyy` and `HH:mm` on separate lines, parsed in `Europe/Berlin` (today the
  same offset as `Europe/Amsterdam`, but the zone is a property of the chain's country, not of
  the parser).

The Tomra template in Germany reuses the Albert Heijn rules for the transaction line and timestamp,
with these differences:

- *Months:* German abbreviations. Most coincide with the Dutch ones; the differences are March
  (`MRZ` or `MÄR`, Dutch `MRT`), May (`MAI`, Dutch `MEI`) and December (`DEZ`, Dutch `DEC`). Until a
  German bon from those months is seen, both spellings are accepted for each.
- *Amount:* the first amount after `LEERGUTBON`, printed white on black. Vision reads inverted
  text, but the euro sign is more often lost there, so the `E 0.55` / `C 0.55` repairs apply.
- *Store:* the header carries `EDEKA` and the merchant's name (EDEKA markets are independently
  owned), then street and German postcode. The merchant name is kept as the store's label.
- *Voucher number:* `Bon` followed by three digits, cross-checked with barcode digits 9–11.

=== Rendering

CoreImage's `CICode128BarcodeGenerator` produces Code 128 (it has no EAN-13 generator, @sec-ean13),
but it chooses the code set itself. The same rules as for EAN-13 apply to its output: one pixel per
module, scaled by a whole number of screen pixels with interpolation off, black on white. A unit
test renders both sample payloads above and decodes them with Vision, which must return the
same 24 and 32 digits. If the generator's output fails that test, a subset C encoder is about forty lines (the
one in `lib.typ` is twenty) and keeps the app independent of the generator's choices.

=== Sharing <sec-share-templates>

The share button (`BonImageRenderer`, @sec-widget) draws every voucher as an Albert Heijn
emballagebon. A REWE or EDEKA voucher shared that way would look wrong to the person receiving
it and, worse, would not import as what it is: the parser would take it for a Dutch bon. Every
supported format therefore gets its own template, chosen from the code's format and chain:

#dtable(
  columns: (auto, 1fr, 1fr),
  header: ("Template", "Layout (as in)", "Barcode"),
  [Tomra NL (Albert Heijn)], [@fig-bon: header, filiaal, address, `Emballagebon`, amount, Tomra footer.], [EAN-13],
  [REWE], [@fig-rewe: header, address, `Nr.`, date and time lines, `Total:` and `EUR`.], [Code 128, 24 digits],
  [Tomra DE (EDEKA)], [@fig-edeka: header, address, `LEERGUTBON`, `Bon`, inverted amount, Tomra footer.], [Code 128, 32 digits],
  [Generic], [Label, store if any, amount if any; no chain look.], [As stored],
)

The rules for every template:

- *Only stored facts.* A template draws only what the app stores: payload, chain, store address,
  amount, issue time, and the fields the payload itself carries (REWE `Nr.`, EDEKA `Bon`). Lines
  the app does not keep, such as REWE's line items, the Tomra transaction line or the machine
  number, are omitted rather than invented. The parser already treats them as optional.
- *Round trip per template.* The existing test (render a voucher, read it back through
  `PhotoCodeReader` and `BonParser`, compare payload, store, amount and issue time) runs once per
  template, and additionally compares the detected chain and format. A template that does not
  round-trip is a failing test, not a cosmetic defect.
- *Barcode as printed.* The barcode is drawn in the voucher's own symbology, with the rendering
  rules of @sec-ean13, never in a substitute such as QR (@sec-qr-test), whatever the till experiment
  shows: the picture is for importing into another phone, not for the till.
- *Marked as a copy.* The paper is the bearer instrument (@sec-rewe), so the picture carries a
  footer line, "Kopie · CodeShare" ("Kopie" is the word in Dutch and German alike), and no logo, so that it cannot pass for the original paper. The parser ignores the line.
- *No match, generic.* A code of an unknown format, or one that is not a deposit voucher at all,
  is shared with the generic template, which still round-trips payload and label.

=== Data model and sync

The local and server schemas already carry a `symbology` column, and the sealed payload already
includes it (@sec-sealed-meta), so codes need no migration: a Pfandbon is a code with
`symbology = "code128"`; the format (REWE, Tomra DE) is derived from the payload's shape and
need not be stored. `expires_at`, optional so far, gets a value for German bons: 31 December of
the issue year plus three. The list sorts and warns by it (a month ahead), and an expired bon
is shown as such rather than hidden, since a market may still accept it. Stores do:

- *Store key.* Because a Pfandbon is redeemable only where it was printed, the store is what a
  voucher is grouped and redeemed by, as the filiaal number is for Albert Heijn. Stores are keyed
  by filiaal number, and a Pfandbon prints none. The key becomes
  `(chain, key)`, as already anticipated for Jumbo. Until further bons settle whether
  unexplained barcode digits identify the market, a German store's key is derived from the
  normalised address (postcode, street, house number). The server's immutable-address rule
  (first bon prevails) then holds trivially, since the address *is* the key.
- *Geocoding.* The server accepts a new store only if PDOK geocodes it *inside the Netherlands*.
  A Berlin store would be refused with 400. German stores need a second geocoder behind the same
  rules (restricted to the postcode, coordinates validated inside a bounding box, an unreachable
  geocoder saves the store unverified). OpenStreetMap's Nominatim with `countrycodes=de` and
  `postalcode` fits the volume (its usage policy allows one request per second); the squatting
  limit of ten new stores per user per day applies unchanged.
- *Display.* "Albert Heijn · city" becomes "chain · city" (for EDEKA, "EDEKA <merchant> · city") from the existing `Chain` enum; grouping,
  nearest-store sorting and the at-store card work per store and need no change. The Bonuskaart
  remains Albert Heijn's.

== Open questions <sec-rewe-open>

- *Unexplained digits.* REWE digits 1–12, EDEKA digits 4–8 and 12–31: market, machine, or date?
  One sample of each cannot say. A second bon from the same machine, one from another machine in
  the same market, and one from another market answer it, and decide the store key.
- *Tomra elsewhere.* Whether German Tomra bons at other chains share the `980` format, and whether
  the Dutch Tomra template at Albert Heijn and the German one differ in more than the months.
- *Screen scanning.* Whether German tills read a Code 128 from a phone screen has not been tested,
  and, because the paper is the bearer instrument, a market may refuse a screen even if its
  scanner reads it. The app's code screen is therefore a convenience, and the paper bon should be
  carried until the code is marked used. Code 128 is wider than EAN-13 (167 modules at 24 digits and 211 at 32, against 95, before quiet
  zones), so the code screen should prefer landscape for it.
- *Other chains.* Lidl and Aldi print their own Pfandbons. The template and chain split and the
  `(chain, key)` store key are intended to make each a set of rules rather than a redesign.

#lesson[The scanner was restricted to the one symbology of the one sample. That kept the
first version small and its validation strict, but it encoded "a voucher is an EAN-13" as an
assumption no test could reveal; the first bon from a second chain did. Reading the failing
artefact with an independent decoder settled the symbology in minutes, before any code was
changed. The second German sample then showed that "a chain" was the wrong unit too: two chains
share a printer template, and one chain's two vouchers need not share a barcode format.]
