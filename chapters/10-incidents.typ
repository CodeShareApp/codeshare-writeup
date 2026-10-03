#import "../lib.typ": *

= Incidents and lessons learned

Review detects defects in code. This chapter records incidents that were not code defects, or that
could be observed only in real operation.

== The app icon that was a real voucher

The first app icon depicted an airliner whose livery was an EAN-13 barcode, an unrequested
decorative addition by an agent. The barcode encoded the *real, unredeemed sample bon*. Anyone who
saw the icon could, in principle, have redeemed it at the issuing store. It was removed the same
evening and replaced with a design selected by the owner from sketches: two fanned tickets on teal, with *decorative* bars that encode nothing
(`design/make_icon.py` draws them as rectangles of chosen widths, not as a symbology).

The old icon remains in an early commit. For this reason `CLAUDE.md` prohibits pushing the
repository anywhere until that bon is redeemed, and this document does not reproduce its digits.

#lesson[Creative additions by an agent are output that requires review. Any real identifier (a
barcode, a token, an address) is data that must not leak into artefacts, including decorative
ones.]

== Repository description inconsistent with code

The GitHub description of holy-shit-api stated ASP.NET. The code is Go with Echo. The plan adopted
conventions from the repository contents, and the discrepancy is now recorded in `CLAUDE.md` so that
the description is not relied upon.

== Misplaced workspaces

The first jj workspaces were created as siblings of the project in `~/working`, cluttering the
directory that contains every project. They were moved to `workspaces/` inside the project (git-ignored,
`/workspaces/` in `.gitignore`), and "jj workspaces go under the project" became a global rule.
Parallel workspaces also install to the same Simulator and replace one another's app; a separate
simulator device is therefore used for manual runs.

== Concurrent Xcode session

An Xcode instance open on the project rewrote the hand-written `pbxproj` and reformatted the String
Catalogs while agents were editing them from the command line. The changes were reverted, and the
rule is now that Xcode is closed before the project is edited manually.

== Defects observable only on real devices

- *Brightness restored to 0* after leaving the barcode screen (@sec-brightness).
  The Simulator has no brightness control, so only a phone could reveal the defect.
- *Vision in the Simulator* requires CPU-only mode and barcode revision 1. Without these settings,
  photo import appears defective in the Simulator while functioning on the phone, which is the
  converse case.

== Provisioning from the command line

`xcodebuild` cannot create provisioning profiles for a free team, so any new capability (App Groups
for the widget and share extension) requires a single manual step in Xcode. The widget branch has
been ready for that check since it was written; the check is its only outstanding dependency.

== Policy restriction on infrastructure changes

`terraform apply` was blocked for the agent by policy. The agent did not attempt to circumvent the
restriction; it prepared the units and presented the plans, and the owner applied them.
Infrastructure that incurs cost and holds production data is an appropriate place for a manual
approval step.

== Deployment to a shared host

The first deploy targeted a server that runs the owner's other production applications. The
following measures kept it free of incidents: check mode before every provisioning run, the
`only_projects` filter, reloading PostgreSQL instead of restarting it, Caddy validate-then-reload
with automatic rollback, and loading the other sites afterwards to confirm that they still respond.
The deploy's own health check uses the public URL from the deploying machine, the same path by
which phones reach the server.

== Separation of test devices from members' phones

All testing takes place in the Simulator, against a local DEV server (`LiveServerTests` runs two
phones in one process), and on the developer's own phone. Other household members' phones receive a
build only once it is known to be good, and never one that might modify their vouchers in an
untested way. The wipe sequencing in @sec-wipe applies the same principle to the developer's own
phone.
