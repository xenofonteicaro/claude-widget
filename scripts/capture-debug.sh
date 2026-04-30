#!/bin/bash
# Debug capture: writes the full Claude statusLine or Codex hook JSON to a log.
# Use this to verify which limit keys your local CLI emits.
#
# After 1-2 turns, inspect ~/.aiusagewidget-debug.log and confirm that keys
# such as `rate_limits`, `five_hour`, `seven_day`, or Codex usage windows exist.

set -e

LOG="$HOME/.aiusagewidget-debug.log"
if [ -n "$1" ]; then
  INPUT="$1"
else
  INPUT=$(cat)
fi

# Append timestamp + raw JSON (one record per line, JSON Lines style).
{
  printf '{"_at":"%s","raw":' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s' "$INPUT"
  printf '}\n'
} >> "$LOG"

# Don't print anything to stdout — keeps the TUI status line empty during testing.
