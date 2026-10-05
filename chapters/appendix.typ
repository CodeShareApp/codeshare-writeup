#import "../lib.typ": *

#counter(heading).update(0)
#set heading(numbering: "A.1")

= Glossary

#set par(justify: false)
#set terms(spacing: 0.9em)

/ AAD: Additional authenticated data. Bytes an AEAD authenticates but does not encrypt; here the
  code id, household id and key version, so that a blob cannot be moved between them.
/ AEAD: Authenticated encryption with associated data. ChaCha20-Poly1305 is one: it encrypts and
  produces a tag that detects any change to ciphertext or AAD.
/ App Group: A shared container that lets an app and its extensions (widget, share extension)
  read the same files.
/ BCBP: IATA's Bar Coded Boarding Pass standard (Resolution 792); a fixed-width text in PDF417,
  Aztec, QR or Data Matrix (@sec-boarding).
/ Biesieklette: A chain of bicycle parkings; a bike is collected by presenting the QR code it was
  checked in with (@sec-parking).
/ Blind index: A keyed hash (here HMAC-SHA256) stored next to encrypted data so that a server can test
  equality without learning the value.
/ Bonuskaart: Albert Heijn's loyalty card; an EAN-13 barcode pinned at the top of the Home screen.
/ Code 128: A variable-length barcode (ISO/IEC 15417) with a mod-103 check symbol; subset C
  packs two digits per symbol. Used by the REWE Pfandbon.
/ ECDH: Elliptic-curve Diffie–Hellman. Two key pairs derive the same shared secret; used to wrap K
  to a device's public key.
/ Emballagebon: The paper deposit voucher a return machine prints; redeemable only at that store.
/ EAN-13: The 13-digit retail barcode (GS1). 95 modules; the last digit is a check digit.
/ Einweg, Mehrweg: German single-use (25 cents) and refillable (8 or 15 cents) deposit containers.
/ Filiaal: A store branch; its number keys stores and groups vouchers.
/ Glowie curve: This document's name for NIST P-256 (secp256r1), which CryptoKit calls `P256`; the
  only curve the Secure Enclave offers. "Glowie" is internet slang for intelligence-agency
  personnel, popularised by Terry A. Davis (TempleOS); the name alludes to the NSA-generated
  parameters, whose seed was never explained.
/ HKDF: HMAC-based key derivation (RFC 5869). Turns key material into independent subkeys by
  `salt` and `info` label.
/ jj: Jujutsu, the Git-compatible VCS used here; workspaces are its multiple working copies.
/ K: The 32-byte household key, versioned. Never sent in the clear, never used directly.
/ Key holder: A device holding a wrap of the household's current key version.
/ LWW: Last write wins: the version with the later `updatedAt` (client clock, ms) is kept.
/ Pfandbon, Leergutbon: The German deposit voucher (REWE's and EDEKA's names); both samples carry
  a Code 128, of 24 and 32 digits (@sec-rewe).
/ PNR: Passenger name record; here the six-character booking reference on a boarding pass.
/ PDOK Locatieserver: The Dutch government's free geocoder, used by the server for new stores.
/ Secure Enclave: Apple's hardware key store. Keys created there cannot be exported.
/ Soft delete: Setting `deleted_at` instead of removing the row, so the delete can sync.
/ Statiegeld: The Dutch deposit on cans and bottles.
/ Strict server: oapi-codegen's mode where each operation's responses are distinct Go types.
/ UUIDv7: A UUID whose first 48 bits are Unix milliseconds; sortable by creation time.
/ Wrap: K encrypted to one device's public key (ECIES-style), plus an authentication tag.
/ xid8 / xmin: PostgreSQL's 64-bit transaction id, and the oldest transaction still running in a
  snapshot; together the sync cursor.

#set par(justify: true)

= Byte layouts

All integers big-endian; `uuid(x)` is the UUID's 16 raw bytes in RFC 9562 order; `‖` is
concatenation. Source of truth: the doc comment at the top of `HouseholdCrypto.swift`.

#dtable(
  columns: (auto, 1fr),
  header: ("Item", "Definition"),
  [seal_key], [HKDF-SHA256(ikm K, salt uuid(household_id), info `codeshare/v1/seal`, 32)],
  [mac_key], [HKDF-SHA256(ikm K, salt uuid(household_id), info `codeshare/v1/mac`, 32)],
  [Seal AAD (36)], [uuid(code_id) ‖ uuid(household_id) ‖ u32(key_version)],
  [`sealed`, `nonce`], [ChaChaPoly ciphertext ‖ 16-byte tag; 12-byte random nonce],
  [Sealed plaintext], [Sorted-key JSON, `v: 2`; dates as integer ms; nil fields omitted],
  [`payload_mac` (32)], [HMAC-SHA256(mac_key, UTF-8 payload)],
  [Public key (65)], [`0x04 ‖ X ‖ Y` (x963); base64 with padding in the API (88 chars)],
  [wrap_key], [HKDF-SHA256(ikm ECDH(e, recipient_pk), salt epk ‖ recipient_pk, info `codeshare/v1/wrap`, 32)],
  [Wrap AAD (36)], [uuid(household_id) ‖ u32(key_version) ‖ uuid(recipient_device_id)],
  [Wrap box (60)], [ChaChaPoly combined: nonce (12) ‖ encrypted K (32) ‖ tag (16)],
  [Wrap tag (32)], [HMAC-SHA256(auth_key, epk ‖ box ‖ uuid(household) ‖ u32(version) ‖ uuid(device) ‖ recipient_pk)],
  [`wrappedKey` (92)], [box ‖ tag],
  [auth_key: invite], [HKDF(ikm s, salt recipient_pk, info `codeshare/v1/wrap-auth/invite`, 32)],
  [auth_key: rotation], [HKDF(ikm K#sub[n], salt uuid(household_id), info `codeshare/v1/rotate`, 32) — for version n+1],
  [auth_key: self], [HKDF(ikm ECDH(d, own pk), salt uuid(household_id), info `codeshare/v1/wrap-auth/self`, 32)],
  [Join QR], [`{"d":"<uuid>","k":"<base64url 65 B>","s":"<base64url 32 B>","v":2}`, unpadded base64url, QR level M],
  [Sync cursor], [`<generation uuid>:<xid8>`, opaque to clients],
)

= Command cheat-sheet

=== iOS (in `ios/`)

```bash
xcrun simctl boot "iPhone Air"        # if the simulator is unresponsive
xcodebuild test -project CodeShare.xcodeproj -scheme CodeShare \
  -destination 'platform=iOS Simulator,name=iPhone Air'
# two phones against a local DEV server (start it first: mise run serve)
TEST_RUNNER_CODESHARE_LIVE_TESTS=1 xcodebuild test ... \
  -only-testing:CodeShareTests/LiveServerTests
```

=== Backend (in `backend/`)

```bash
mise run db:setup      # local codeshare + codeshare_test, migrated
mise run test          # integration tests (sets TEST_DATABASE_URL)
mise run vet           # go vet, release and -tags DEV
mise run gen           # after editing api/openapi.yaml or db/
mise run dev           # :8080 with air (DEV build, has /api/dev/session)
mise run db:new add_expiry_to_codes   # never type a version by hand
mise run deploy        # build, test, ship to the shared server
```

=== Provisioning (in `shared-infrastructure/`)

```bash
mise run check -- --tags postgres                      # dry run
mise run provision -- --tags projects -e only_projects=codeshare
mise run provision -- --tags backups
```

=== After restoring a database dump

```sql
-- every phone resyncs in full
UPDATE database_generation SET id = uuidv7();
```

=== Rolling back a deploy (on the server)

```bash
ls -1 /usr/local/lib/codeshare/releases       # newest last
sudo ln -sfn /usr/local/lib/codeshare/releases/<previous> \
  /usr/local/lib/codeshare/current
sudo service codeshare restart
```
