#import "../lib.typ": *

= A second Dutch chain: Dirk <sec-dirk>

A *specification*, from two real statiegeldbonnen printed on 12 October 2026 in one Dirk van den
Broek supermarket in The Hague, by two different machines. Both have since been redeemed, so their
real values are given and serve as test vectors.

== Two machines, two layouts

#dtable(
  columns: (auto, 1fr, 1fr),
  header: ("Field", "Dirk, Tomra 70 Single", "Dirk, second machine (vendor not printed)"),
  [Barcode], [EAN-13 `9805621353327`, valid check digit.], [EAN-13 `9811073535563`, valid check digit.],
  [Amount in barcode], [No (`060` does not occur).], [No; nor the bon or machine number.],
  [Heading], [`Statiegeldbon`; logo above.], [Logo only.],
  [Amount], [`€ 0.60`, white on black, point decimal (the Tomra NL template).], [`Totaal:Eur0,50`, comma decimal, no space after `Eur`.],
  [Line items], [`4x Blik 0.60`, then a count and total line.], [`2 × Pet 25ct Eur0,50`.],
  [Store], [Street and city only: `Torenstraat 132A`, `'s-Gravenhage`. *No postcode.*], [`Dirk`, street, postcode and city: `2513 BW Den Haag`.],
  [Store number], [None.], [None (a 11-digit `Machinenummer`).],
  [Voucher number], [In the transaction line.], [`Bon-nummers:175588`; `Machinenummer: 20231403701`.],
  [Timestamp], [Tomra: `20:28:05 12-OKT-2026`.], [`12-10-2026 - 20:28:40`.],
  [Validity], [*Printed:* "Statiegeldbon is een jaar geldig na uitgifte".], [None printed.],
  [Transaction line], [`800401-90370000-15322-00`.], [None.],
)

== What changes in the spec

- *The `98x` prefix is not Tomra's.* A non-Tomra machine prints `981`; Tomra machines print `980`
  in the Netherlands and `980` or `984` in Germany (@sec-rewe). The prefix marks a refund receipt
  or coupon in GS1's sense and is not a vendor or chain signal. An EAN-13 beginning `98` is a
  deposit voucher candidate; the chain comes from the text.
- *The transaction line is per machine model, not per vendor.* The Tomra 9 bons (Albert Heijn and
  EDEKA) begin `606657-90360001-`; the Tomra 70 Single begins `800401-90370000-`. Neither identifies
  a store.
- *Dirk has no store number.* Stores are keyed by `(chain, normalised address)`, as for the German
  chains (@sec-rewe), which the sealed household stores make cheap (@sec-sealed-stores).
- *City names need an alias table.* The Tomra bon prints the municipality's official name,
  `'s-Gravenhage`; the other machine prints `Den Haag`. Both must normalise to one store, and
  without a postcode on the Tomra bon the street and city alone have to identify it; geocoding on
  the phone (MapKit, PDOK) resolves `'s-Gravenhage` correctly.
- *Expiry can be printed.* Dirk's Tomra bon states one year from issue. `expires_at` is set from
  the printed rule where there is one (issue time plus one year), from the law where there is
  none (Germany: @sec-rewe), and stays empty otherwise. The emballagebon's "no printed expiry"
  (@fig-bon) is a property of Albert Heijn's bons, not of Dutch bons.
- *The amount comes from the text.* As on Albert Heijn's bons, the EAN-13 holds no amount. The
  parser reads `€ 0.60` after the logo (Tomra) or `Totaal:Eur0,50` (comma decimal, `Eur` glued to
  the number), and cross-checks with the line items.

== Parser rules

Chain detection reads the logo text (`Dirk`) or the store line. Then:

- *Tomra NL template* (`Tomra 70 Single` or `Tomra 9` in the footer): the Albert Heijn rules,
  with `Statiegeldbon` accepted wherever `Emballagebon` is, and an address without a postcode.
- *Dirk second machine:* `Bon-nummers:` and `Machinenummer:` lines; timestamp `dd-MM-yyyy - HH:mm:ss`
  in `Europe/Amsterdam`; amount after `Totaal:` with `Eur` and a comma decimal; street above a
  postcode line as on the emballagebon.

== Open questions

- Whether Dirk's validity rule (one year) also applies to bons from the second machine, which
  prints none.
- Which vendor makes the second machine, and whether its `981` bons are accepted at the till from
  a screen.
- Whether Albert Heijn bons are honoured at Dirk or the reverse (assumed not: a bon is redeemable
  only where it was printed).
