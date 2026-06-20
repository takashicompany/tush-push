#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUNDLE="$ROOT/plugins/tush-push"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE"

for path in \
    .codex-plugin \
    .claude-plugin \
    hooks \
    scripts \
    skills \
    messages.example.json \
    CLAUDE.md
 do
    cp -R "$ROOT/$path" "$BUNDLE/"
 done

printf 'Synced Codex plugin bundle: %s\n' "$BUNDLE"
