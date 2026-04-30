#!/bin/bash
# Production capture script.
# Reads the statusLine stdin JSON from Claude Code and writes the
# `rate_limits` portion atomically into the App Group container that the
# ClaudeWidget app and its Widget Extension share.

set -e

INPUT=$(cat)
TARGET_DIR="$HOME/Library/Group Containers/group.icaro.claudewidget"
mkdir -p "$TARGET_DIR"

TMP="$TARGET_DIR/latest.json.tmp"
DEST="$TARGET_DIR/latest.json"

printf '%s' "$INPUT" | jq -c '.rate_limits // {}' > "$TMP"
mv "$TMP" "$DEST"

# stdout is left empty — Claude Code's TUI status line will be blank.
# Customize here if you want to chain other status-line content.
