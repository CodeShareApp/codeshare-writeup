# CodeShare: a study write-up

A technical report on CodeShare, a private iPhone app for a household to keep and share
Albert Heijn deposit vouchers (emballagebonnen) and a Bonuskaart, with a Go backend that
stores only end-to-end-encrypted blobs. It covers the constraints, the architecture, the
iOS app, the backend, the cryptography (household keys, Secure Enclave device keys, key
wraps, rotation), sync, deployment, and what code review caught along the way.

Written in [Typst](https://typst.app/). The values on every bon, barcode and screenshot in
it are made up, except the two German samples in chapter 12 (one redeemed, one already public) and
a used parking tag in chapter 13.

## Building

With [mise](https://mise.jdx.dev/):

```sh
mise trust
mise run build    # → codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty]-dark.pdf
                  #   codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty]-light.pdf  (day mode)
```

The PDF's name carries the local build time and the short commit id of the revision it
was built from (jj's `@-`, or git's `HEAD` in a plain git clone), plus `-dirty` when the
working copy has uncommitted changes, so every copy can be traced to its source. PDFs are
git-ignored.

Without mise: `./build.sh` (needs Typst 0.15 on `PATH`; `./build.sh light` builds one
theme), or plainly `typst compile codeshare.typ` from the repository root, adding
`--input theme=light` for the day-mode version.

## Layout

- `codeshare.typ` — title page, contents, and the chapter includes.
- `lib.typ` — template, the dark and light palettes, callouts, tables, and an EAN-13 renderer.
- `chapters/` — one file per chapter, plus the appendix (glossary, commands).
- `images/` — the app icon and an app screenshot.
- `dark.tmTheme` — syntax-highlighting theme for code blocks in the dark version (the light
  version uses Typst's default highlighting).

## Releases

Pushing a version tag (`git tag v2026.10.04 && git push origin v2026.10.04`), or running the
Release workflow from the Actions tab with a version, runs `.github/workflows/release.yml`,
which builds both themes and publishes them as a GitHub release. The assets keep the
build names, timestamp and commit included (`codeshare-<YYYYMMDD-HHMM>-<sha>-dark.pdf`,
`…-light.pdf`), so every copy can be traced to its source. Link to a release's own assets
(`releases/download/<tag>/<file>`).
