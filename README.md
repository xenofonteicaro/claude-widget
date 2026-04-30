# AI Usage Widget

A native macOS menu-bar item and desktop WidgetKit widget for local AI CLI usage limits.

It was originally built for Claude Code's `statusLine.rate_limits` payload and now also accepts Codex hook/usage payloads when they include compatible limit fields. The app does not call any network API and does not need auth tokens; it only reads a normalized JSON file in its App Group container.

## Data Shape

The app reads:

```json
{
  "five_hour": { "used_percentage": 34, "resets_at": 1777580000 },
  "seven_day": { "used_percentage": 12, "resets_at": 1778000000 },
  "seven_day_sonnet": { "used_percentage": 4, "resets_at": 1778000000 }
}
```

All keys are optional. `scripts/capture.sh` normalizes Claude and Codex input into this shape. It supports direct `rate_limits`, nested `usage.rate_limits`, `limits`, and array-style windows with labels such as `session`, `5h`, `week`, `weekly`, `7d`, or `sonnet`.

## Build

```bash
./scripts/setup.sh
open AIUsageWidget.xcodeproj
```

Or from the CLI:

```bash
xcodebuild -project AIUsageWidget.xcodeproj -scheme AIUsageWidget \
  -configuration Debug -destination 'platform=macOS' build
```

The app group is `group.icaro.aiusagewidget`. If Apple's portal rejects the bundle/app group IDs for your team, replace `com.icaro.aiusagewidget` and `group.icaro.aiusagewidget` in `project.yml`, entitlements, `AppGroup.swift`, and `SharedTypes.swift`, then rerun `./scripts/setup.sh`.

## Claude Code Setup

Install the capture script:

```bash
mkdir -p ~/.claude/widget
cp scripts/capture.sh ~/.claude/widget/capture.sh
chmod +x ~/.claude/widget/capture.sh
```

Add a top-level `statusLine` entry to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/widget/capture.sh"
  }
}
```

With `jq`:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '. + {statusLine: {type: "command", command: "~/.claude/widget/capture.sh"}}' \
  ~/.claude/settings.json.bak > ~/.claude/settings.json
```

Start a new Claude Code session. Existing sessions do not re-read `settings.json`.

## Codex Setup

Install the same capture script for Codex:

```bash
mkdir -p ~/.codex/widget
cp scripts/capture.sh ~/.codex/widget/capture.sh
chmod +x ~/.codex/widget/capture.sh
```

Add the command to `~/.codex/hooks.json`. If you already have hooks, add this command alongside the existing commands rather than replacing them:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.codex/widget/capture.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.codex/widget/capture.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.codex/widget/capture.sh"
          }
        ]
      }
    ]
  }
}
```

Codex passes hook JSON as an argument; Claude pipes JSON through stdin. `capture.sh` handles both.

Current Codex plan limits are account-dependent, and [OpenAI's Codex plan help](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan) says usage limits vary by plan and task complexity. The widget can display Codex limits only when the local Codex payload includes window/reset fields. Use the debug script below if your menu bar stays empty.

## Debug Payloads

To inspect what a CLI is actually sending:

```bash
cp scripts/capture-debug.sh ~/.codex/widget/capture-debug.sh
chmod +x ~/.codex/widget/capture-debug.sh
```

Point a Codex hook or Claude `statusLine.command` at `capture-debug.sh`, run a turn, then inspect:

```bash
tail -1 ~/.aiusagewidget-debug.log | jq .
```

Switch back to `capture.sh` once you confirm the payload shape.

## Runtime

The menu-bar label shows Claude and Codex separately:

```text
C 34%/12%w · X 40%/20%w
```

`C` is Claude and `X` is Codex. The first number is the short/session window. The `w` number is the weekly window. The popover shows separate sections for both sources with countdowns to reset.

Refresh cadence depends on the source CLI. Claude refreshes when `statusLine` runs and writes `claude.json`. Codex refreshes when configured hooks fire and writes `codex.json`. `latest.json` is still written for WidgetKit/backward compatibility. The app also ticks every minute so countdown text updates without rewriting the file.

## Troubleshooting

- `not configured`: no `latest.json`, `claude.json`, or `codex.json` exists in `~/Library/Group Containers/group.icaro.aiusagewidget`.
- `Stale`: the file exists, but no capture has updated it in 30 minutes.
- Empty Codex values: inspect `~/.aiusagewidget-debug.log`; your Codex hook payload may not expose usage windows yet.
- Widget missing fresh data: remove and re-add the desktop widget after rebuilding; WidgetKit can cache placeholder timelines during development.

## Files

```text
AIUsageWidget/                         macOS menu-bar app
AIUsageWidgetExtension/                WidgetKit extension
scripts/capture.sh                     Claude/Codex payload normalizer
scripts/capture-debug.sh               Raw payload logger
scripts/setup.sh                       XcodeGen/signing bootstrap
project.yml                            XcodeGen project definition
```
