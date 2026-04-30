#!/bin/bash
# Phase 1 debug capture — writes the FULL statusLine stdin JSON to a debug log.
# Use this to verify which `rate_limits` keys Claude Code emits for your plan,
# specifically whether `seven_day_sonnet` is present.
#
# After 1-2 turns of Claude Code activity, inspect ~/.claudewidget-debug.log
# and confirm that `rate_limits.{five_hour,seven_day,seven_day_sonnet}` are present.

set -e

LOG="$HOME/.claudewidget-debug.log"
INPUT=$(cat)

# Append timestamp + raw JSON (one record per line, JSON Lines style).
{
  printf '{"_at":"%s","raw":' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s' "$INPUT"
  printf '}\n'
} >> "$LOG"

# Don't print anything to stdout — keeps the TUI status line empty during testing.
