#!/bin/bash
# Production capture script.
# Reads Claude Code statusLine JSON or Codex hook JSON and writes a normalized
# rate-limit payload into the App Group container that AIUsageWidget reads.

set -e

if [ -n "$1" ]; then
  INPUT="$1"
else
  INPUT=$(cat)
fi

TARGET_DIR="${AI_USAGE_WIDGET_TARGET_DIR:-$HOME/Library/Group Containers/group.icaro.aiusagewidget}"
mkdir -p "$TARGET_DIR"

TMP="$TARGET_DIR/latest.json.tmp"
DEST="$TARGET_DIR/latest.json"
SOURCE=$(printf '%s' "$INPUT" | jq -r '
  if (.rate_limits? != null or .rateLimits? != null) then "claude"
  elif (.usage? != null or .limits? != null or .codex? != null or .type? != null) then "codex"
  else "latest"
  end
' 2>/dev/null || printf 'latest')
SOURCE_TMP="$TARGET_DIR/$SOURCE.json.tmp"
SOURCE_DEST="$TARGET_DIR/$SOURCE.json"

NORMALIZED=$(printf '%s' "$INPUT" | jq -c '
  def n:
    if type == "number" then .
    elif type == "string" then tonumber?
    else null
    end;

  def ts:
    if type == "number" then .
    elif type == "string" then (tonumber? // fromdateiso8601?)
    else null
    end;

  def pct:
    (.used_percentage // .usedPercent // .percent_used // .percentUsed // .usage_percent // .usagePercent) as $direct
    | if $direct != null then ($direct | n)
      elif (.used != null and .limit != null) then (((.used | n) / (.limit | n)) * 100)
      elif (.current != null and .limit != null) then (((.current | n) / (.limit | n)) * 100)
      elif (.remaining != null and .limit != null) then (((.limit | n) - (.remaining | n)) / (.limit | n) * 100)
      elif (.remaining_percentage != null) then (100 - (.remaining_percentage | n))
      elif (.remainingPercent != null) then (100 - (.remainingPercent | n))
      else null
      end;

  def reset:
    (.resets_at // .reset_at // .resetAt // .window_reset // .windowReset // .expires_at // .expiresAt // .until) | ts;

  def normalized_limit:
    (pct) as $pct
    | (reset) as $reset
    | if $pct != null and $reset != null then
        {used_percentage: $pct, resets_at: $reset}
      else
        null
      end;

  def compact:
    with_entries(select(.value != null));

  def limit_label:
    (.key // .name // .label // .window // .period // .type // "") | tostring | ascii_downcase;

  def named($needles):
    if type == "array" then
      map(select(limit_label as $l | any($needles[]; . as $needle | $l | contains($needle)))) | .[0]
    else
      null
    end;

  def payload:
    .rate_limits
    // .rateLimits
    // .usage.rate_limits
    // .usage.rateLimits
    // .usage.limits
    // .limits
    // .codex.rate_limits
    // .codex.rateLimits
    // .codex.limits
    // .;

  payload as $p
  | if ($p | type) == "array" then
      {
        five_hour: (($p | named(["five_hour", "5h", "session", "short"])) | normalized_limit),
        seven_day: (($p | named(["seven_day", "7d", "week", "weekly", "long"])) | normalized_limit),
        seven_day_sonnet: (($p | named(["seven_day_sonnet", "sonnet"])) | normalized_limit)
      } | compact
    else
      {
        five_hour: (($p.five_hour // $p.fiveHour // $p.session // $p.session_limit // $p.short_window // $p.shortWindow) | normalized_limit),
        seven_day: (($p.seven_day // $p.sevenDay // $p.week // $p.weekly // $p.week_limit // $p.long_window // $p.longWindow) | normalized_limit),
        seven_day_sonnet: (($p.seven_day_sonnet // $p.sevenDaySonnet // $p.sonnet // $p.sonnet_week // $p.sonnetWeekly) | normalized_limit)
      } | compact
    end
')

printf '%s\n' "$NORMALIZED" > "$TMP"
printf '%s\n' "$NORMALIZED" > "$SOURCE_TMP"
mv "$TMP" "$DEST"
mv "$SOURCE_TMP" "$SOURCE_DEST"

# stdout is left empty. Customize here if you want to chain other status-line
# content for Claude Code.
