#!/bin/sh
# Compiles codeshare.typ to codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty][-light].pdf: local time,
# the short commit id of the revision being built, "-dirty" if the working copy has changes,
# "-light" for the day-mode theme. With no argument it builds both themes; `./build.sh dark`
# or `./build.sh light` builds one. Extra typst options (e.g. --font-path) go in $TYPST_ARGS.
# With jj (colocated): the revision is @- and "dirty" means @ is not empty. Without jj
# (a plain git clone): HEAD and `git status --porcelain`.
set -eu
cd "$(dirname "$0")"

if [ -d .jj ] && command -v jj >/dev/null 2>&1; then
    sha=$(jj log --no-pager --color=never -r @- --no-graph -T 'commit_id.short(7)')
    [ "$(jj log --no-pager --color=never -r @ --no-graph -T 'empty')" = true ] || sha="$sha-dirty"
elif git rev-parse --git-dir >/dev/null 2>&1; then
    sha=$(git rev-parse --short=7 HEAD)
    [ -z "$(git status --porcelain)" ] || sha="$sha-dirty"
else
    sha=nogit
fi

base="codeshare-$(date +%Y%m%d-%H%M)-$sha"
themes=${1:-"dark light"}
for theme in $themes; do
    case $theme in
        dark) out="$base.pdf" ;;
        light) out="$base-light.pdf" ;;
        *) echo "unknown theme: $theme (dark or light)" >&2; exit 1 ;;
    esac
    # shellcheck disable=SC2086
    typst compile ${TYPST_ARGS:-} --input theme="$theme" codeshare.typ "$out"
    echo "$out"
done
