#import "../lib.typ": *

= End-to-end encryption in depth

The governing rule is: *the server never receives a plaintext code or a key, and performs no
cryptography.* All operations in this chapter run on the phones, in CryptoKit, in
`ios/CodeShare/Services/HouseholdCrypto.swift`, `DeviceKey.swift` and `KeyRing.swift`. The byte
encodings are fixed by tests to vectors computed independently in Go (`crypto/ecdh`), so that a
second client could reproduce them bit for bit.

== Threat model

The protected assets are barcodes worth a few euros each at a single store, and a loyalty card.
Considered in isolation, these assets may not justify end-to-end encryption. The justification
concerns the *server*: it runs on a host shared with other production applications, its backups
are stored in S3, and signup is open. End-to-end encryption (E2EE) bounds the consequences of a
breach of any of these components: an attacker obtains only sealed blobs and store addresses that
are printed on paper in any case.

#dtable(
  columns: (1fr, 1fr),
  header: ("Defended against", "Not defended against"),
  [Reading codes from the database, a backup or the logs], [A compromised or unlocked phone (it holds K)],
  [A server that substitutes its own household key (at join, or by faking a rotation)], [A server that *withholds* data: drops codes, wraps or whole syncs (availability)],
  [A server that edits status, store or timestamps of a code], [Someone who photographs the join QR before the new member scans it],
  [A server that replays an older, authentic copy of a code], [Traffic analysis: how many codes, for which stores, when],
  [Wrapping the key to a device the server registered], [Loss of every device (no recovery code yet)],
)

== Server-side key or end-to-end?

#dtable(
  columns: (auto, 1fr, 1fr),
  header: ("", "Server-side key", "End-to-end (chosen)"),
  [Server sees], [Everything, decrypted in memory], [Sealed blobs; plaintext metadata only],
  [Breach of DB + env file], [All codes], [Nothing useful],
  [Dedupe], [Trivial (compare payloads)], [Needs a blind index (HMAC)],
  [Adding a member], [Server adds a row], [Key must travel phone → phone (QR scan, wraps)],
  [Lost all phones], [Recoverable], [Codes lost unless a recovery code exists],
  [Server code], [Must do crypto correctly], [Does none; stores bytes],
)

The additional cost of E2EE falls almost entirely on the phones and on one in-person procedure
(scanning a QR code). For members of one household, who meet in person routinely, this procedure
imposes no practical cost.

== The key hierarchy

#fig(
  canvas(60mm, {
    node(48mm, 0mm, 40mm, 12mm, fill: c.deep)[*K* household key \ 32 random bytes · v = n]
    node(0mm, 21mm, 40mm, 14mm)[HKDF-SHA256 \ info `codeshare/v1/seal` \ salt uuid(household_id)]
    node(96mm, 21mm, 40mm, 14mm)[HKDF-SHA256 \ info `codeshare/v1/mac` \ salt uuid(household_id)]
    arrow((58mm, 12mm), (25mm, 21mm))
    arrow((78mm, 12mm), (111mm, 21mm))
    node(0mm, 42mm, 40mm, 14mm, stroke: c.blue)[*seal_key* \ ChaChaPoly over \ each code's content]
    node(96mm, 42mm, 40mm, 14mm, stroke: c.violet)[*mac_key* \ HMAC-SHA256(payload) \ = `payload_mac`]
    arrow((20mm, 35mm), (20mm, 42mm))
    arrow((116mm, 35mm), (116mm, 42mm))
    node(48mm, 36mm, 40mm, 20mm, stroke: c.amber, fill: c.amberbg)[*wraps of K* \ one per (device, version) \ ECDH + HKDF + ChaChaPoly \ + HMAC tag]
    arrow((68mm, 12mm), (68mm, 36mm), color: c.amber)
  }),
  [K is never used directly. Two HKDF subkeys perform all operations on codes; K itself is only
  transported, wrapped, to devices.],
) <fig-keys>

Subkeys are used because applying one key to two algorithms (an AEAD and a MAC) is usually
harmless but occasionally catastrophic; HKDF with distinct `info` labels renders the two keys
independent at the cost of two function calls. The household id as salt binds them to the
household. Versioned labels (`v1`) leave room for a format change.

== Sealing a code

Each code is sealed with *ChaCha20-Poly1305* (CryptoKit `ChaChaPoly`) under `seal_key`, with a
fresh random 12-byte nonce per seal:

#bytes-bar((
  ("nonce", 12, c.accent),
  ("ciphertext (JSON)", 40, c.blue),
  ("tag", 16, c.violet),
))
#v(-0.4em)
#align(center, text(size: 8pt, fill: c.muted)[API: `nonce` = 12 bytes; `sealed` = ciphertext ‖ 16-byte tag (ciphertext length varies)])

#bytes-bar((
  ("uuid(code_id)", 16, c.accent),
  ("uuid(household_id)", 16, c.blue),
  ("ver", 4, c.amber),
), height: 8mm)
#v(-0.4em)
#align(center, text(size: 8pt, fill: c.muted)[AAD, 36 bytes (ver = u32 key_version): authenticated, not encrypted. A blob cannot be moved to another code, household or key version.])

```swift
static func seal(_ content: SealedContent, codeID: UUID, key: HouseholdKey,
                 nonce: ChaChaPoly.Nonce = ChaChaPoly.Nonce()
) throws -> (sealed: Data, nonce: Data) {
    let box = try ChaChaPoly.seal(
        try content.encoded(), using: key.sealKey, nonce: nonce,
        authenticating: try sealAAD(codeID: codeID,
            householdID: key.householdID, keyVersion: key.version))
    return (Data(box.ciphertext) + Data(box.tag), Data(nonce))
}
```

=== Why not XChaCha20?

The original plan specified XChaCha20-Poly1305 with 24-byte nonces, which CryptoKit lacks; it
would have required swift-sodium or a hand-built HChaCha20. The relevant question is whether
random 96-bit nonces are safe. A nonce collision under one key is the failure mode, and with random nonces its
probability after _n_ messages is about #emph[n]#super[2]/2#super[97]. The usual guidance is to stay below
2#super[32] messages per key. A household seals a code each time it is edited: hundreds, perhaps
thousands, of seals over the lifetime of a key, a margin of more than twenty orders of magnitude.
The design therefore uses plain `ChaChaPoly`, avoids a dependency, and keeps every primitive inside
CryptoKit.

#note[`u32(key_version)` uses `UInt32(exactly:)` and throws. Review found that the first version
trapped (terminated the app) on a negative or very large version sent by the server. A malicious
or defective server must not be able to terminate a client with a single integer.]

== What the sealed blob contains <sec-sealed-meta>

The plaintext is JSON with sorted keys, version `v: 2`:

```
{"amountCents","deletedAt","filiaalNr","issuedAt","kind","label",
 "payload","status","symbology","updatedAt","usedAt","v":2}
```

Dates are integer milliseconds since 1970; nil fields are omitted. In addition to the secret
fields (payload, symbology, label, amount), the content includes *kind, store, status and every
timestamp*, which also exist as plaintext columns. Version 1 contained only the secret fields.
Review noted that the plaintext columns lay outside the AEAD, so a server could set a code to
`used`, mark it deleted, revert its status or move it to another store, and phones would accept
the change. On pull, a phone now takes *every* field from the sealed content (`SyncMerge.localCode`); the plaintext columns
exist only so the server can do last-write-wins, dedupe and sync.

== The blind index

Deduplication across a household's phones requires the server to detect identical barcodes
without seeing them. For this purpose each phone sends a blind index,

#align(center)[`payload_mac = HMAC-SHA256(mac_key, payload)`,]

which the server keeps unique per household.

A plain SHA-256 of the payload would be insufficient, because the input space is small. An EAN-13
has at most twelve free digits, the check digit is determined, and vouchers from one chain share a
prefix, leaving far fewer candidates. A GPU computes billions of SHA-256 hashes per second; every
hashed voucher would be recovered within seconds to minutes. An HMAC under a key the server does not hold cannot be brute-forced
without that key.

This has a far-reaching consequence: `mac_key` is derived from K, so when K rotates, every MAC
changes. A code left under the old MAC would escape deduplication. Rotation is therefore *eager*: the rotating phone must
reseal and re-MAC every code, and the server refuses a PUT under an older key version with 422
(@sec-rotation).

== Device keys in the Secure Enclave, on the glowie curve

Each phone holds a long-term key-agreement key. The first implementation used Curve25519 keys kept
in the Keychain. These were replaced by *Secure Enclave keys on the glowie curve* (the only curve
the Secure Enclave offers), because an enclave key is hardware-bound and *non-extractable*: no
backup, no exfiltration short of a jailbreak, and no software defect can copy it off the phone. The Keychain
holds only an opaque handle (`dataRepresentation`) that is useless on any other device.

```swift
guard SecureEnclave.isAvailable else {
    throw DeviceKeyError.noSecureEnclave }
var error: Unmanaged<CFError>?
guard let access = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    .privateKeyUsage, &error)
else { throw error!.takeRetainedValue() as Error }
return DeviceKey(backing: .enclave(
    try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access)))
```

The code encodes two choices: *no user presence* (no Face ID prompt), so that a background sync can
unwrap; and *after first unlock, this device only*. There is no software fallback on a real phone;
a phone without an enclave receives an explicit error and cannot share. Only Simulator builds use a software
glowie-curve key. Public keys travel as 65-byte uncompressed points `0x04 ‖ X ‖ Y`; the server
validates them with Go's `ecdh.P256().NewPublicKey`, which rejects compressed points, the point at
infinity and points off the curve. Any other input, including a residual 32-byte Curve25519 key,
yields a 400, and the database `CHECK`s the length.

Review added two robustness fixes. A *failed Keychain read* (a locked phone after a reboot) is not
treated as "no key", so a new device key is never generated over an unreadable old one. A stored
handle that no longer restores (after a backup is restored onto another phone) is reported and
replaced, rather than disabling sharing permanently.

== Wrapping K to a device

To provide a device with the household key, a phone that holds K creates a *wrap*:

+ a fresh ephemeral glowie-curve key pair _e_;
+ shared = ECDH(_e_, recipient_pk), the 32-byte X coordinate;
+ wrap_key = HKDF-SHA256(shared, salt = epk ‖ recipient_pk (65 + 65 bytes), info `codeshare/v1/wrap`);
+ box = ChaChaPoly(K) under wrap_key, AAD = uuid(household) ‖ u32(version) ‖ uuid(recipient device);
+ tag = HMAC-SHA256(auth_key, epk ‖ box ‖ uuid(household) ‖ u32(version) ‖ uuid(device) ‖ recipient_pk).

#bytes-bar((
  ("nonce", 12, c.accent),
  ("K encrypted", 32, c.blue),
  ("Poly1305 tag", 16, c.violet),
  ("HMAC tag (auth)", 32, c.amber),
))
#v(-0.4em)
#align(center, text(size: 8pt, fill: c.muted)[`wrappedKey`, 92 bytes (the server allows 256), sent with the 65-byte ephemeral public key])

Steps 1–4 constitute ordinary ECIES. Step 5 was added in review and is described in the following
section.

== Authenticating wraps

The original design relied on the camera: the inviting phone wraps K to the public key read from
the joiner's QR code, so the server cannot cause it to wrap to a server key. This holds, but the
*joiner* had no means of distinguishing a wrap from another member's phone from a wrap created by
the server. A malicious server could supply the joining phone with a K′ of its own; the joiner
would then seal every new code under a key known to the server. The same attack applied later:
increment `key_version`, answer the next PUT with 422, and offer a "rotation" wrap.

In the corrected design, every wrap carries an HMAC tag, keyed by something the server never sees. A phone unwraps
only wraps whose tag verifies under an authenticator it trusts, checked *before* any decryption.

```swift
switch auth {
case .invite(let secret):     // the joiner's one-time QR secret s
    return HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: secret),
        salt: recipientPublic, info: inviteAuthInfo, outputByteCount: 32)
case .rotation(let previous): // version n vouches for n+1
    guard previous.householdID == householdID,
          previous.version == keyVersion - 1
    else { throw WrapError.wrongContext }
    return HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: previous.rawBytes),
        salt: bytes(householdID), info: rotateAuthInfo, outputByteCount: 32)
case .device(let device):     // ECDH(d, d·G): only this enclave can
    return try device         // compute it
        .sharedSecret(with: device.publicKey)
        .hkdfDerivedSymmetricKey(using: SHA256.self,
            salt: bytes(householdID), sharedInfo: deviceAuthInfo,
            outputByteCount: 32)
}
```

The self-wrap authenticator merits explanation. An enclave key cannot be exported, so it cannot be
used directly as an HMAC key. The enclave *can*, however, perform ECDH with any public key,
including its own. ECDH(_d_, _d_·_G_) is a secret that only the holder of _d_ can compute, so HKDF
of it is a symmetric key unique to this device and household.

== The join flow

#fig(
  canvas(86mm, {
    let col(x, t) = {
      node(x, 0mm, 36mm, 9mm, fill: c.deep)[#t]
      place(top + left, dx: x + 18mm, dy: 9mm, line(length: 75mm, angle: 90deg, stroke: (paint: c.hair, thickness: 0.8pt, dash: "dashed")))
    }
    col(0mm, [Joining phone])
    col(50mm, [Server])
    col(100mm, [Member's phone (has K)])
    let msg(y, x1, x2, body, color: c.accent) = {
      arrow((x1, y), (x2, y), color: color)
      label(calc.min(x1 / 1mm, x2 / 1mm) * 1mm + 2mm, y - 4.2mm, w: 46mm)[#body]
    }
    msg(17mm, 18mm, 68mm)[① `POST /api/devices` (pk)]
    msg(25mm, 68mm, 18mm)[device id]
    node(1mm, 31mm, 34mm, 13mm, stroke: c.amber, fill: c.amberbg, size: 7.2pt)[② shows QR: \ id · pk · secret _s_]
    arrow((35mm, 37.5mm), (100mm, 37.5mm), color: c.amber, dash: "dashed")
    label(46mm, 33.3mm, w: 50mm)[③ camera, in person — never via server]
    node(101mm, 44mm, 34mm, 13mm, size: 7.2pt)[④ wrap K to pk, \ tag with HKDF(_s_)]
    msg(64mm, 118mm, 68mm)[⑤ `POST …/wraps` (joins!)]
    msg(73mm, 68mm, 18mm)[⑥ `GET /api/devices/{id}/wraps`]
    node(1mm, 76mm, 34mm, 10mm, size: 7.2pt)[⑦ verify, unwrap, \ self-wrap, forget _s_]
  }),
  [Joining a household. The secret _s_ never touches the server; the server cannot produce a wrap
  the joiner accepts. The joiner polls step ⑥ every 3 s for up to 10 minutes.],
) <fig-join>

The following details were each established through a defect or a review finding:

- *The QR names the device by id and key.* Public keys were formerly globally unique and assigned
  first come, first served, so anyone who saw a QR could register its key first and squat it. Keys are now
  unique per user, and a wrap must name a device id *and* matching key.
- *Uploading the first wrap for a non-member's device makes its owner a member*, under a row lock
  on the household. The lock was introduced to prevent two concurrent joins from both taking the
  last of two places; the member cap is being removed, so a household has no size limit.
- *Joining only through the camera.* A Debug-only "paste the invite" path and a copy button were
  removed: the secret must reach the new member's phone in person.
- *The joiner self-wraps before forgetting _s_* (step ⑦). Without it, the joiner's only wrap
  verified under _s_, which is discarded after joining; after a sign-out it could not recover K
  without a rescan. A live two-phone test now signs the joiner out and back in.
- *Fresh K only for a create this phone started.* An early version generated a new key for any
  household with no key holders; now only while a creation this phone started is pending, it is the
  sole member and the version is 1.

== Rotation <sec-rotation>

Rotation (`POST /api/households/{id}/key-rotations`) stores wraps of K#sub[n+1] and bumps
`key_version` in one transaction. Review restricted it to wrapping for *exactly the key holders* (devices
holding a wrap of the current version) rather than every registered device of every member, since a
device registered with a stolen session would otherwise receive the new key. After rotating, the phone
reseals and re-MACs every code; the server refuses older versions (422 with `currentKeyVersion`),
and a phone that missed the rotation fetches its new wrap (authenticated by K#sub[n]) and reseals.
The *server side and the receiving side are implemented*; the control that initiates a rotation
(required after removing a member or losing a phone) is not (Chapter 11).

== What the server can and cannot do

#dtable(
  columns: (1fr, 1fr),
  header: ("The server can", "The server cannot"),
  [Refuse service, drop or withhold codes, wraps or syncs], [Read a payload, label or amount],
  [See how many codes a household has, per store, and when they change], [Change a code's status, store or timestamps unnoticed],
  [Replay an old blob (phones keep a newer local copy, @sec-lww)], [Inject a household key a phone accepts],
  [Learn that two codes are equal (same MAC) within a household], [Learn whether two households hold the same barcode (MAC keys differ)],
  [Register devices for a user whose session it controls], [Get K wrapped to such a device by an honest phone],
)

#warn(title: "Limitations")[
  - *No independent cryptographic audit.* The scheme has been reviewed by automated review agents,
    not by a cryptography specialist, and has not been assessed for production use.
  - *Availability is not protected.* A server can withhold any data. E2EE provides confidentiality
    and integrity only.
  - *The join QR is a bearer secret for a few seconds.* Someone who photographs it before the new
    member scans it, and controls the server, could complete the join first. It is shown briefly,
    in person, and discarded after use.
  - *A compromised phone holds K* and every code. Device keys protect K at rest; they do not protect
    an unlocked phone.
  - *No recovery code yet.* If every phone in the household is lost, the codes are lost (the paper
    bons are not).
  - *Replay protection is per phone.* A phone that never saw the newer version of a code (fresh
    install, full resync) accepts the newest version the server chooses to show it.
]
