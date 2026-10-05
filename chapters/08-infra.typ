#import "../lib.typ": *

= Infrastructure and deployment

== The shared host

The API runs on the FreeBSD server at `64.176.73.190`, next to the author's other
projects. None of Code Share's server configuration resides in the Code Share repositories: the
`codeshare` project entry in `shared-infrastructure` (`group_vars/all/vars.yml`) declares uid 2005,
port 8000, the domains, the backup bucket and the environment, and Ansible turns that into a user, a
database (peer authentication over the Unix socket), directories, an env file, an rc.d service and a
Caddy site with Let's Encrypt certificates.

Provisioning on a host on which other applications depend follows rules recorded in that
repository's README:

- *Dry run first*: `mise run check` (Ansible check mode) shows what would change.
- *Only the target project*: `mise run provision -- --tags projects -e only_projects=codeshare` leaves the
  other projects' env files, services and Caddy sites untouched; an unknown name fails the play
  before any change (a review finding; previously it silently did less).
- *Reload rather than restart*: a new project needs a `pg_hba.conf` line, and PostgreSQL is *reloaded*
  (no dropped connections for the neighbouring services).
- *Validate before reload*: a changed Caddy site is validated together with the whole Caddyfile; if
  invalid, the previous file is restored and the play fails. Review found that the rescue path
  could delete an existing project's working site after a failed template render; it now removes a
  site only if this run created it.
- *Verify the neighbouring services* after any reload: their sites must still respond.

== Deploying a release

`mise run deploy` in `backend/` runs `deploy/deploy.yml` (holy-shit-api's playbook minus the
frontend):

+ `build-release.sh` vets, runs `TestReleaseBinaryHasNoDevSession`, cross-builds a static
  FreeBSD/amd64 binary (`CGO_ENABLED=0`, migrations embedded) and refuses one that contains
  `/api/dev/session`.
+ The tarball is unpacked into `/usr/local/lib/codeshare/releases/<timestamp>`; `current` is pointed
  at it; the service restarts. Its rc.d script runs `./server migrate` first; a failed migration
  keeps the service stopped rather than serving on a partially migrated schema.
+ Health checks: `/health` on the server (retried 10 × 2 s), then `https://codeshare.shop/health`
  *from the deploying machine*, through DNS, Caddy and the certificate (retried 12 × 5 s, because on
  a first deploy Caddy may still be obtaining the certificate; a review finding after the first
  attempt).
+ Releases are pruned to the newest five on every deploy.

Rollback is manual and documented: `current` is pointed at the previous release and the service is
restarted. Migrations are not rolled back; an older binary must be able to start on a newer schema,
and a release whose migration is incompatible with older code requires a fix forward.

== AWS: telemetry and backups

The AWS resources are defined by two Terraform units under
`shared-infrastructure/terraform/projects/codeshare/`:

- *observability* (`modules/app-observability`): the CloudWatch log group `/codeshare/production/app`,
  an IAM user allowed to export OTLP logs, traces and metrics, and an error notifier (a TypeScript
  Lambda) that e-mails every ERROR. The access key is created manually so that the secret remains outside
  the Terraform state, and is stored in the Ansible vault.
- *backups* (`modules/db-backups`): an S3 bucket with 30-day expiry and a put-only IAM user. The
  server runs `pg_dump -Fc` at 06:00 and 20:00, encrypts it with `age` to the SSH keys of the deploy
  user, and uploads it; the server itself cannot decrypt its backups.

`terraform apply` was blocked for the agent by policy; both units were applied manually by the
owner. At the time of writing, telemetry is enabled and the backup job is configured. A backup
contains sealed blobs, wraps and store addresses, which cannot be read without a member's phone.

== Signing and installing on a phone <sec-signing>

Command-line `xcodebuild` can build and sign with an existing provisioning profile, but it *cannot
create* one on a free team ("No Accounts"): a new capability (such as the App Group required by the
widget) requires Xcode's GUI to generate the profile. For this reason the widget branch is on hold:
whether a free Personal Team can provision `group.dev.moroz.CodeShare` is a brief check in Xcode
that no agent could perform. The branch was written defensively for both outcomes (@sec-widget).

Two practical rules resulted. First, Xcode is closed before the `pbxproj` is edited manually (an
open Xcode instance rewrote it, and the string catalogs, without the agents' knowledge; those
changes were reverted). Second, development builds are installed only on the developer's own phone;
other household members' phones receive a build only once it is known to be good.

== Moving to the paid team <sec-paid-team>

A paid membership was bought on 4 October 2026. What it opens, and what the move costs:

#dtable(
  columns: (auto, 1fr),
  header: ("Capability", "Use"),
  [Associated Domains], [Native passkeys: `ASAuthorizationPlatformPublicKeyCredentialProvider` with the entitlement `webcredentials:codeshare.shop` and an `apple-app-site-association` file on the server naming the app. The relying party ID stays `codeshare.shop`, so passkeys created through the page-based flow remain valid; the server needs JSON begin/finish endpoints beside the `/auth` page, which can stay as a fallback.],
  [App Groups], [Provisioned by the team: the widget and share-extension branch (@sec-widget) is no longer blocked on the free-team question.],
  [TestFlight], [Builds for the other members' phones, valid for 90 days instead of 7. The tail of old versions grows from a week to three months, which the server's compatibility rules must now allow for (@sec-wipe).],
  [Push (APNs)], [Possible: a silent push to the other members when a code changes, replacing sync-on-foreground as the main trigger.],
)

*The team identifier changes*, and it prefixes the app's Keychain access group. An app re-signed
by the paid team most likely cannot read the Keychain items written under the Personal Team:
the bearer token, the household key K and the Secure Enclave device key (whose reference is a
Keychain item). The local SQLite database survives only if the bundle identifier is kept, and a
bundle identifier registered by the Personal Team must first be released to the new team. In
effect every phone becomes a new device. The move is therefore sequenced with the wipe below:
both phones on a new build signed by the paid team, a fresh household, codes re-entered from the
local export or paper. The App Group `group.dev.moroz.CodeShare` is registered under the paid
team at the same time. This should be confirmed on one phone before it is relied on.

== Sequencing the glowie-curve switch <sec-wipe>

Moving device keys from Curve25519 to Secure Enclave glowie-curve keys changed the public-key size
from 32 to 65 bytes. Old wraps became unusable, so the server's household data had to be wiped, and the
migration (`20261002204756_glowie_curve_public_keys`) refuses to run while a 32-byte key remains.

The hazard lay on the phone. The build installed at the time treated a *401* as an ordinary
sign-out, and an ordinary sign-out deletes every synced row (Chapter 7). Had the server been wiped
first, the next foreground event on the phone would have received a 401 and deleted every synced
voucher. The order was therefore fixed as follows:

#fig(
  canvas(57mm, {
    let steps = (
      ([1], [Back up the phone's database], c.accent),
      ([2], [Install the build where 401 = "account gone": keep codes, re-tag as never synced], c.accent),
      ([3], [Check on the phone: codes still there, old keys retired cleanly], c.accent),
      ([4], [Wipe the server's household tables], c.amber),
      ([5], [Deploy the glowie-curve backend (migration checks 65-byte keys)], c.amber),
      ([6], [Phone receives 401 → keeps codes; sign in, create household, re-push], c.muted),
    )
    for (i, s) in steps.enumerate() {
      let y = i * 9.4mm
      node(0mm, y, 8mm, 7.4mm, fill: s.at(2), stroke: s.at(2), fg: c.bg)[#text(weight: "semibold", s.at(0))]
      node(11mm, y, 125mm, 7.4mm, stroke: s.at(2), size: 7.8pt)[#align(left, s.at(1))]
      if i < 5 { arrow((4mm, y + 7.4mm), (4mm, y + 9.4mm)) }
    }
  }),
  [The wipe follows the installation of a build that survives it. At the time of writing, the
  phone's database is backed up; steps 4–6 await confirmation of the new build on the phone.],
) <fig-wipe>

The same build also handles an install that still holds a Curve25519 key: it re-tags codes as never
synced *first*, and drops the old key only after that step has succeeded. Review reversed the
original order, which could leave codes tagged with a defunct household and no state from which to
retry.

#lesson[A server change is only as safe as the oldest client that will communicate with it. With
sideloaded builds, the oldest client is whichever build is currently installed on each phone; its
handling of the errors the change will cause must be verified.]

== Domain layout: API moves to `api.` (in progress)

At present `codeshare.shop`, `www.` and `api.` all route to the API. The layout is being changed:

- `api.codeshare.shop` serves the API, including the passkey page at `/auth`;
- `codeshare.shop` and `www.codeshare.shop` serve a static English landing page, built with the
  conventions of the owner's Astro landing-page projects and served by Caddy on the same host.

The WebAuthn *Relying Party ID stays `codeshare.shop`*. Passkeys are scoped to a registrable domain,
and an origin of `https://api.codeshare.shop` is valid for RP ID `codeshare.shop`, so existing
passkeys remain valid. The changes are `RP_ORIGIN` (to `https://api.codeshare.shop`) and the app's
API base URL (`APIServer.swift`).

The safety argument of the previous section applies again: during the switch an *old* build still
calls the apex and receives the landing page's 404. A 404 is not a 401, so no sign-out occurs and no
local data is modified; requests fail and sync retries later. (In the current code a 404 is reported
as a failed request rather than as "offline"; the effect on data is the same.)

State at the time of writing: the app's switch (`APIServer.production` → `https://api.codeshare.shop`)
has landed in the main line; the landing page (`landing/`, Astro + Tailwind) and the corresponding
backend and Caddy changes reside in a separate workspace, not yet merged or deployed.
