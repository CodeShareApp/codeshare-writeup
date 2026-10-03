# codeshare-writeup

Typst technical report on CodeShare (the sibling repos codeshare-ios, codeshare-api and
codeshare-web in `~/working/codeshare/`). **Public:** fresh history, meant to be published.

- **Always build with `mise run build`.** PDFs carry the build timestamp and the source
  revision in their name (`codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty].pdf`, `build.sh`); they
  are git-ignored. Commit (`jj commit`) before building one to share, so it isn't `-dirty`.
- Neutral technical-report register. Device keys are on NIST P-256, called "the glowie
  curve" throughout (introduced with a footnote at first use, chapter 2, and in the
  glossary); library identifiers like `SecureEnclave.P256` keep their names.
- Nothing private goes in: no real bon or the sample bon's EAN/store/transaction id, no
  names of people, no account ids or keys, no other projects on the shared server, no IPs
  except the public server's. Every bon, barcode and screenshot value is made up.
- Images live in `images/`, referenced root-relative (`/images/...`); compile from the
  repository root.
