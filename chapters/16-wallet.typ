#import "../lib.typ": *

= A code wallet: cards and Apple Wallet passes <sec-wallet>

A *specification*. With parking tags, generic codes and boarding passes the app holds more than
vouchers: it is a wallet of codes for a household. Two consequences are specified here: cards
become a section of their own, and codes can be issued as Apple Wallet passes.

== Cards

The Bonuskaart has had its own slot at the top of the home screen. A library card showed that it
is one of a kind of code: a *card*, shown again and again, never used up, without amount or
expiry. The Bibliotheek Den Haag card carries a *Code 39* barcode whose text is exactly the
printed customer number (11 digits; decoded from the owner's card with zxing-cpp, symbology
identifier `]A0`, no check character), and a printed library number (`NL-0800270000`) that
identifies the library organisation and is not in the barcode. The owner's number is live, being
half of the library login, and is not reproduced; examples use `12345678901`.

- *Kind* `card`. The Bonuskaart becomes the first card rather than a special case.
- *"Kaarten" section* at the top of the home screen, replacing the Bonuskaart slot: pinned cards
  in a user-chosen order.
- *Owner.* Vouchers belong to the household; a library card belongs to one person. A card names
  its holder ("van Karol"), shown on the code screen. Whether another member may present it is
  the issuer's rule, not the app's.
- *Place.* A card may be tied to an issuer with locations (Albert Heijn stores, library
  branches); near one, the at-location card shows it, as the at-store card shows vouchers.
- *Rendering.* Code 39 is one of the linear symbologies the app draws itself (@sec-generic).
  Whether the library's self-service machines read it from a screen is untested.

== Apple Wallet passes

The paid team (@sec-paid-team) can register a *Pass Type ID*. The app then issues any code as a
Wallet pass: on the lock screen near a store, on the Apple Watch (which answers the watch question
of @sec-qr-test without a watch app), and double-click-to-show at the till.

=== What Wallet can display

#dtable(
  columns: (auto, 1fr),
  header: ("Code", "As a Wallet pass"),
  [REWE and EDEKA Pfandbons (Code 128)], [Natively.],
  [Parking tags, generic QR, Aztec, PDF417], [Natively.],
  [Albert Heijn vouchers and the Bonuskaart (EAN-13)], [*Not as EAN-13*: Wallet offers only QR, PDF417, Aztec and Code 128. The same digits as Code 128 or QR work only if the till accepts them, which is exactly the till experiment (@sec-qr-test, now with Code 128 as a third variant).],
  [Library card (Code 39)], [Not as Code 39; same question for the library's scanners.],
  [Boarding passes], [Airlines issue their own; the app does not reissue them.],
)

A code whose symbology Wallet cannot show, and whose substitute has not passed a test at the
relevant scanner, is not offered as a pass.

=== Pass styles and content

Vouchers are *coupon* passes, cards *store card* passes, parking tags *generic* passes. A voucher's
pass carries its store's coordinates in `locations`, so Wallet offers it on the lock screen near
that store ("€ 4.20 bij Albert Heijn Grote Marktstraat"). The coordinates go only into the pass
on the phone; the server never sees them (@sec-sealed-stores).

=== Signing without showing the server the code

A pass is a zip of `pass.json`, images, a `manifest.json` listing the SHA-1 of every file, and a
PKCS \#7 detached signature of the manifest, made with the Pass Type ID certificate. That private
key must not be in the app, where anyone could extract it and sign passes in Code Share's name.
The server holds it, but sending it `pass.json` would show it the barcode and break the rule that
the server never sees a code.

The manifest makes this unnecessary: the phone builds the pass, computes the manifest, and sends
*only the manifest* to `POST /api/passes/sign`; the server returns the signature. The server sees
SHA-1 hashes. Because a payload such as an EAN-13 is guessable from its hash, `pass.json` always
contains a random 128-bit `serialNumber`, which makes the hash of the file unguessable.

The cost is that the server signs manifests it cannot inspect: an account could have any pass
signed under Code Share's Pass Type ID. Signup is open, so the endpoint is limited per user and
per day, like store creation was, and signing can be restricted to members of a household.

=== Updates without a web service

Wallet's update mechanism (a web service the pass points to, plus push) would require the
server to serve pass contents. Instead, the app keeps its passes current itself: an app may read,
replace and remove passes of its own Pass Type ID (`PKPassLibrary`). When a voucher is marked
used on any phone, every member's app removes or voids its pass on the next sync. Passes on a
phone whose app has not run since then remain until it does.

== Open questions

- Code 128 and QR at the Albert Heijn till (@sec-qr-test), now also deciding Wallet support for
  Albert Heijn.
- Library self-service machines and phone screens.
- Whether a pass should exist per member's phone or only on request.
