#!/bin/sh
set -e

die() {
    echo "$1" >&1
    exit 1
}

DEST="$1"
REF="${2:-HEAD}"

SRC="$(dirname "$(readlink -f "$0")")"

[ "$SRC" ] || die "Usage: $0 <dest/ip_repo/ospreyEVG/> [revision]"
[ -d "$DEST" ] || die "Destination directory must exist.  Manually create before initial export."

echo "Export from: $SRC"
echo "       to: $DEST"
echo "       Ref: $REF"

TDIR="$(mktemp -d)"
trap 'rm -rf "$TDIR"' TERM KILL HUP EXIT

export GIT_DIR="${SRC}/.git"
git archive --format=tar "$REF" | tar -C "$TDIR" -x
git log -n1 "$REF" > "$TDIR/Version.txt"

rsync -av \
 --delete \
 "$TDIR/" "$DEST/"
