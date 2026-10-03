#!/bin/sh
# Compiles codeshare.typ to codeshare-<YYYYMMDD-HHMM>-<sha>[-dirty].pdf: local time, the
# short commit id of the revision being built, "-dirty" if the working copy has changes.
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

out="codeshare-$(date +%Y%m%d-%H%M)-$sha.pdf"
typst compile codeshare.typ "$out"
echo "$out"
