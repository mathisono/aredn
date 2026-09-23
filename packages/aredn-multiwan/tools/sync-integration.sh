#!/bin/sh
# Synchronize the standalone PollyWAN package source into an AREDN checkout.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODE=check
AREDN_DIR="${2:-}"

usage()
{
    echo "usage: $0 {check|apply} /path/to/aredn" >&2
    exit 2
}

[ $# -eq 2 ] || usage
MODE="$1"
AREDN_DIR="$2"
case "$MODE" in check|apply) ;; *) usage ;; esac

[ -d "$AREDN_DIR/.git" ] || { echo "not an AREDN git checkout: $AREDN_DIR" >&2; exit 1; }
DEST="$AREDN_DIR/packages/aredn-multiwan"
mkdir -p "$DEST"

RSYNC_ARGS="-a --delete --exclude .git"
if [ "$MODE" = check ]; then
    # A clean dry-run prints no changed paths.
    changes="$(rsync -rnic --delete --exclude .git "$ROOT/" "$DEST/" || true)"
    if [ -n "$changes" ]; then
        printf '%s\n' "$changes"
        echo "PollyWAN repositories are not synchronized" >&2
        exit 1
    fi
    echo "PollyWAN standalone root matches packages/aredn-multiwan"
    exit 0
fi

# shellcheck disable=SC2086
rsync $RSYNC_ARGS "$ROOT/" "$DEST/"
"$ROOT/tests/verify.sh"
"$0" check "$AREDN_DIR"

echo "Synchronized $DEST from $ROOT"
