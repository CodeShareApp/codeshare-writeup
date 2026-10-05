#import "../lib.typ": *

= Parking tags: Biesieklette <sec-parking>

Like @sec-rewe, this chapter is a *specification*, not a description of built code. Biesieklette
runs a chain of bicycle parkings. A cyclist checks in with a tag carrying a QR code and gets the
bike back only by presenting the same code. A lost or forgotten tag
means a bike that cannot be collected without an argument at the counter, and a tag in one
member's pocket is no help to the member who comes to collect the bike. Both are the problems the
app already solves for vouchers.

== Anatomy of a tag

#let tag-qr = ("111111100110001111111", "100000101000101000001", "101110101101001011101", "101110101001001011101", "101110100100101011101", "100000100001001000001", "111111101010101111111", "000000001010000000000", "100000101101011001110", "101010010001110110101", "110110110000101100110", "001001011001111100001", "010011110011111110010", "000000001100100000001", "111111100101010010000", "100000100100001000110", "101110100101010010000", "101110100101111001000", "101110100101110111011", "100000100011111001101", "111111101000100100100")

#fig(
  block(width: 46mm, fill: c.blue, inset: 3mm, radius: 3mm, {
    set par(leading: 0.4em, spacing: 0.4em, justify: false)
    text(font: mono-font, size: 9pt, weight: "bold", fill: c.bg, tracking: 0.04em)[BIESIE \ KLETTE]
    v(2mm)
    align(center, block(fill: c.paper, inset: 2mm, radius: 1.5mm, {
      qr-matrix(tag-qr, module: 0.85mm, ink: c.ink, bg: c.paper)
      v(0.5mm)
      align(center, text(font: mono-font, size: 8pt, fill: c.ink, tracking: 0.08em)[F12345])
    }))
  }),
  [A parking tag as the scanner should read it (fictitious number; the QR code is a real
  rendering of `F12345` and decodes with an off-the-shelf reader).],
) <fig-tag>

Three tags from a photograph of the older design were decoded with zxing-cpp. Each QR code
contains *exactly the text printed under it*: one capital letter and five digits (`F12345` in @fig-tag), as
plain text, with no URL, prefix or check character. A current tag, from the owner, carries
*three letters and seven digits*: `RGF0057506`, received on 3 October 2026 and since used to
collect the bike, so reproducing it unlocks nothing. Decoded from the owner's photograph with
zxing-cpp, its QR holds exactly `RGF0057506` (plain QR, error-correction level M), as printed, so
the rule holds for both designs. The current tag is green and carries the municipality's brand,
"Den Haag Fietst!", and a bicycle; *the name Biesieklette does not appear on it*. From this:

#dtable(
  columns: (auto, 1fr),
  header: ("Property", "Consequence"),
  [Payload = printed id], [OCR of the printed id is a cross-check of the QR read, as the printed EAN-13 digits are for the bars, and a tag whose QR is damaged can be entered by hand.],
  [Short alphanumeric], [Fits a version-1 QR (21 × 21 modules) in alphanumeric mode at level M; the app regenerates the code from the text instead of storing a photo.],
  [No check character], [A one-character OCR misread produces another valid-looking id. The QR read is preferred; an id from OCR alone is confirmed by the user.],
  [No location, no time], [The tag does not say where the bike is or since when. Both come from the phone at check-in.],
)

== How it fits the model

A tag is a code like any other: payload, symbology (`qr`), label, status, timestamps. Its
differences are in meaning, not in shape:

- *Kind.* A new kind, beside vouchers and the Bonuskaart: `parking`. It has no amount.
- *Lifecycle.* Scanning a tag at check-in creates the code with `issuedAt` = now: the bike is
  *parked*. Collecting the bike marks it used: *collected*. The existing used/unused status covers
  this; only the wording differs ("Parked since 08:12" and "Collected").
- *Reuse of tags.* The same physical tag is handed out again to later cyclists. Payloads are
  unique across all rows (`v3-unique-payload`, @sec-grdb), so a second check-in with a tag seen
  before finds the existing row. For a parking tag, saving it again resets that row to parked with
  the new check-in time and location, rather than reporting a duplicate.
- *Location.* A parking is a place of a chain, like a store, but the tag prints no address. At
  check-in the app proposes the nearest known Biesieklette parking from the phone's location
  (MapKit), or a new one named by the user, and the user confirms.

=== Privacy: the location stays sealed

Plaintext location plus plaintext timestamps would tell the server where a household's bikes
stand and when they were left and collected, day after day. The parking is therefore a sealed
household store like any other (@sec-sealed-stores): its name and coordinates live only in sealed
content, and the code's kind, status and times are sealed too. The plaintext `client_updated_at`
the server needs for last-write-wins remains, as for every code: that the household *changed a
code* at 08:12 is visible to the server; that it parked a bike, and where, is not.

=== Display and sharing

- *Home screen.* Parked tags appear above vouchers with "Parked since" and the parking's name.
  Near a parking with a parked bike, the at-location card shows the tag first.
- *Code screen.* The QR is drawn as the barcodes are (one pixel per module, whole-number scaling,
  black on white, full brightness), with the id in large text below it for the attendant to read
  aloud or type.
- *Collect.* Showing the code offers "Collected", with undo, as "used" does for vouchers.
- *Share.* The share template (@sec-share-templates) for a tag is a tag look-alike as in
  @fig-tag, with "Kopie · Code Share" and no logo, round-tripping payload, kind and parking name.

=== Scanning

`DataScannerViewController` and `VNDetectBarcodesRequest` gain `.qr`. A QR whose text matches
one of the known id shapes, `^[A-Z][0-9]{5}$` (older tags) or `^[A-Z]{3}[0-9]{7}$` (current
tags), and whose surrounding text contains "Biesieklette" or "Den Haag Fietst", or a printed id
equal to the payload, is a parking tag. The id shape and the printed id are the reliable signals:
the brand on the tag belongs to whoever commissioned the parking, not to the operator. Any other QR is saved as a generic code, without questions (@sec-generic). The
patterns are deliberately narrow and live with the chain's rules, so a future tag design with a
different id shape falls into "generic", not into a misfiled voucher, and can be changed into
a parking tag with one tap.

#note(title: "Tested")[*The code is accepted from a phone screen.* The owner collected a bike
with the current tag `RGF0057506` shown on a phone screen instead of the physical tag. For
Biesieklette, the app can therefore replace the tag at the counter, not merely back it up.
Whether another household member may collect the bike with it remains open (below).]

== Open questions

- *Current tags.* Whether the three letters mean something (a location, a series).
- *Time limits and fees.* Whether a parking has a maximum stay or charges per day; if so,
  `expires_at` gets a value at check-in and the home screen warns before it.
- *One bike, many members.* Whether a household member who did not park the bike may collect it
  with the code alone.
