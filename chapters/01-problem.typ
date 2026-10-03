#import "../lib.typ": *

= The problem

== Statiegeld and the paper it leaves behind

The Netherlands charges a deposit, _statiegeld_, on cans and plastic bottles: 15 cents on a
can or a small bottle, 25 cents on a large one. The deposit is refunded when the empty
containers are fed into a reverse vending machine. At an Albert Heijn supermarket this machine
(a Tomra) does not pay out cash; it prints a paper voucher, an _emballagebon_, worth the total, which the till accepts as
store credit.

Three properties of the voucher determine the design of the project:

- *It is redeemable only at the issuing store.* A bon printed at one Albert Heijn branch has
  no value at another. The store is identified on the bon by its _filiaal_ (branch) number.
- *It carries no printed expiry date*, so bons accumulate. Small amounts (55 cents, 1.20 euro)
  are kept in wallets and pockets and are frequently forgotten.
- *Several people collect them.* Members of one household return bottles at different stores,
  and any one of them may be the person present at the till of the issuing store. The design
  does not limit the number of members.

The alternatives are limited. Albert Heijn does not offer cash refunds. Some deposit machines
at other retailers pay out by bank transfer (SEPA), but none is located near the office. The
voucher therefore remains a paper artefact, and the practical question becomes: _which bons does
the household hold, of what value, for which store, and can the barcode be presented at the till
without the paper?_

With the Albert Heijn Bonuskaart (the loyalty card, also an EAN-13 barcode) added, the
requirements of a small private app follow directly: scan a bon once, keep it on every phone in
the household, group by store, display the barcode large and bright at the till, and mark it as
used.

#note[It was confirmed early in the project that Albert Heijn tills read a barcode from a phone
screen, including from a photograph of a barcode. The remainder of the design depends on this
observation.]

== Anatomy of a bon

The parser in the app was developed against a single real bon (kept in `docs/` and still
unredeemed; for this reason its barcode is not reproduced here). @fig-bon reproduces the layout
with fictitious values. The order of lines is stable, and the parser relies on it: the street is the line above the
postcode, the amount follows "Emballagebon", the barcode digits are a line of 13 digits with a
valid check digit.

#let bonline(body, al: left, size: 7.6pt, weight: "regular") = align(al, text(font: mono-font, size: size, fill: c.ink, weight: weight, tracking: 0.06em, body))

#fig(
  block(width: 64mm, fill: c.paper, inset: (x: 6mm, y: 5mm), radius: 1pt, {
    set par(leading: 0.45em, spacing: 0.45em, justify: false)
    bonline(al: center, size: 9pt, weight: "bold")[Albert Heijn]
    v(1mm)
    bonline(al: center)[Filiaal: 4520]
    bonline(al: center)[Grote Marktstraat 1]
    bonline(al: center)[2511 AB Den Haag]
    v(2mm)
    bonline(al: center, size: 8.4pt, weight: "bold")[Emballagebon]
    bonline(al: center, size: 11pt, weight: "bold")[€ 0.55]
    v(1mm)
    align(center, ean13("2087654321017", module: 0.4mm, height: 11mm, ink: c.ink, bg: c.paper))
    v(1mm)
    bonline[1x Blik #h(1fr) 0.15]
    bonline[1x PET-25ct #h(1fr) 0.25]
    bonline[1x PET-15ct #h(1fr) 0.15]
    bonline[3 stuks #h(1fr) 0.55]
    v(1mm)
    bonline[Tomra 9]
    bonline[123456-78900001-12345-00]
    bonline[18:42:10 01-OKT-2026]
  }),
  [An emballagebon as interpreted by the parser (fictitious store, amount and barcode; the barcode is a
  real EAN-13 rendering of `2087654321017`, drawn by the same algorithm the app uses).],
) <fig-bon>

The information the bon provides, and the information it lacks, is as follows:

#dtable(
  columns: (auto, 1fr),
  header: ("Field", "Notes"),
  [Filiaal number], [The key for everything store-related. Vouchers are grouped and redeemed by it.],
  [Street, postcode, city], [Used to geocode the store (for "nearest store first"). Dutch postcode: four digits, first not 0, two letters.],
  [Amount], [*Not* encoded in the barcode, as far as one sample shows. Read from the `€ x.xx` line, falling back to the line items' sum.],
  [EAN-13], [The voucher itself. The app regenerates the bars from the digits rather than storing a photo.],
  [Timestamp], [Local Dutch time, Dutch month abbreviations (`MRT`, `MEI`, `OKT`). Stored as `issued_at`.],
  [Expiry], [None printed. `expires_at` is optional, for a later household rule.],
)

== What the app had to do

The requirements, as stated in the project plan (`CLAUDE.md`), in order of priority:

+ *Scan* a bon with the camera: barcode and text in one pass, parse filiaal number, address,
  amount and issue time, and let every field be corrected before saving.
+ *Store* codes locally, so that the app functions offline in the shop.
+ *Display* a code full screen, regenerated as crisp bars, at maximum brightness.
+ *Organise*: Bonuskaart at the top, vouchers grouped per store with totals, the nearest store
  first, and a card for the store currently visited listing what can be redeemed there.
+ *Share* between the phones of all household members, without any member having to trust the
  server with the codes.

The last requirement converted a small single-device app into a distributed system with
end-to-end encryption, which is the principal subject of this report.

#lesson[Domain facts were recorded from a real artefact before design began. The single sample
bon determined the parser's line order, the time zone, the month abbreviations, the store-only redemption
rule and the absence of the amount from the barcode. Each of these would otherwise have entered
the schema as an unverified assumption.]
