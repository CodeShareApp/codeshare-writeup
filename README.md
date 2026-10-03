# CodeShare: a study write-up

A technical report on CodeShare, a private iPhone app for a household to keep and share
Albert Heijn deposit vouchers (emballagebonnen) and a Bonuskaart, with a Go backend that
stores only end-to-end-encrypted blobs. It covers the constraints, the architecture, the
iOS app, the backend, the cryptography (household keys, Secure Enclave device keys, key
wraps, rotation), sync, deployment, and what code review caught along the way.

Written in [Typst](https://typst.app/). The values on every bon, barcode and screenshot in
it are made up.

## Building

With [mise](https://mise.jdx.dev/):

```sh
mise trust
mise run build    # → codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty].pdf
```

The PDF's name carries the local build time and the short commit id of the revision it
was built from (jj's `@-`, or git's `HEAD` in a plain git clone), plus `-dirty` when the
working copy has uncommitted changes, so every copy can be traced to its source. PDFs are
git-ignored.

Without mise: `./build.sh` (needs Typst 0.15 on `PATH`), or plainly
`typst compile codeshare.typ` from the repository root.

## Layout

- `codeshare.typ` — title page, contents, and the chapter includes.
- `lib.typ` — template, colours, callouts, tables, and an EAN-13 renderer.
- `chapters/` — one file per chapter, plus the appendix (glossary, commands).
- `images/` — the app icon and an app screenshot.
- `dark.tmTheme` — syntax-highlighting theme for code blocks.
