#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUNDLE="$ROOT/plugins/tush-push"
TMP_BUNDLE="$ROOT/plugins/.tush-push.tmp.$$"
OLD_BUNDLE="$ROOT/plugins/.tush-push.old.$$"

cleanup() {
    rm -rf "$TMP_BUNDLE"
    rm -rf "$OLD_BUNDLE"
}
trap cleanup EXIT HUP INT TERM

rm -rf "$TMP_BUNDLE" "$OLD_BUNDLE"
mkdir -p "$TMP_BUNDLE"

for path in \
    .codex-plugin \
    .claude-plugin \
    hooks \
    scripts \
    skills \
    messages.example.json \
    CLAUDE.md
 do
    cp -R "$ROOT/$path" "$TMP_BUNDLE/"
 done

if [ -e "$BUNDLE" ]; then
    mv "$BUNDLE" "$OLD_BUNDLE"
fi

if ! mv "$TMP_BUNDLE" "$BUNDLE"; then
    if [ -e "$OLD_BUNDLE" ]; then
        mv "$OLD_BUNDLE" "$BUNDLE"
    fi
    exit 1
fi

rm -rf "$OLD_BUNDLE"
trap - EXIT HUP INT TERM

printf 'Synced Codex plugin bundle: %s\n' "$BUNDLE"
