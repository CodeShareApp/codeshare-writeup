# codeshare-writeup

Typst technical report on Code Share (two words in prose; identifiers such as
`ios/CodeShare/` and `codeshare/v1/…` keep theirs; the sibling repos codeshare-ios, codeshare-api and
codeshare-web in `~/working/codeshare/`). **Public:** fresh history, meant to be published.

- **Always build with `mise run build`.** It builds both themes, dark (default) and light
  (`--input theme=light`, palettes in `lib.typ`). PDFs carry the build timestamp and the
  source revision in their name (`codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty]-{dark,light}.pdf`,
  `build.sh`); they are git-ignored. Release assets keep these names (timestamp and
  shasum included); never rename them to fixed names. Links to a release point at that
  release's own assets (`releases/download/<tag>/<file>`), not `latest/download`.
  Colours come only from the palettes: no `rgb(...)` in chapters, so both themes stay
  legible. Commit (`jj commit`) before building one to share, so it isn't `-dirty`.
- Neutral technical-report register. Device keys are on NIST P-256, called "the glowie
  curve" throughout (introduced with a footnote at first use, chapter 2, and in the
  glossary); library identifiers like `SecureEnclave.P256` keep their names.
- Author: Karol Moroz (title page, PDF metadata, README). The report says plainly that the
  project and the report were built with Claude Code (chapter 9, title page).
- Nothing private goes in: no real bon or the sample bon's EAN/store/transaction id, no
  names of people other than the author, no account ids or keys, no other projects on the shared server, no IPs
  except the public server's. Every bon, barcode and screenshot value is made up, except the
  two German samples in chapter 12, cleared by the owner for real values: REWE (redeemed) and
  EDEKA (an old photo already public on the web). Their photos stay out, and so does the EDEKA
  merchant's name (a person's). Likewise the owner's used Biesieklette tag `RGF0057506` in
  chapter 13 (the bike was collected with it).
- Images live in `images/`, referenced root-relative (`/images/...`); compile from the
  repository root.
