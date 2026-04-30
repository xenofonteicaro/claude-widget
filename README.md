# Claude Widget

A native macOS menu-bar item and desktop widget showing your Claude Code usage. Same percentages you see in `/usage`, no network or auth required.

Two of the three windows from `/usage` are surfaced today:

- **Session (5h rolling)**
- **Week — all models (7d rolling)**

The third window in `/usage` (Week — Sonnet only) is **not exposed via Claude Code's `statusLine` pipe**, so it is not shown here. Confirmed empirically against an Enterprise plan; the JSON shape is `{five_hour, seven_day}` only.

## How it works

Claude Code feeds a JSON blob to its `statusLine` command on every turn. Our capture script extracts the `rate_limits` field and writes it atomically to an App Group container that both the menu-bar app and the Widget Extension read.

```
Claude Code  ──statusLine stdin──▶  capture.sh  ──atomic write──▶  ~/Library/Group Containers/group.icaro.claudewidget/latest.json
                                                                                  │
                                                  ┌───────────────────────────────┴────────────────────────┐
                                                  ▼ FSEvents watch                                         ▼ TimelineProvider
                                          ┌───────────────┐                                       ┌────────────────────┐
                                          │  Menu bar app │  ── WidgetCenter.reloadTimelines ──▶  │ Widget Extension   │
                                          │ (NSStatusItem)│                                       │ small/medium/large │
                                          └───────────────┘                                       └────────────────────┘
```

Refresh cadence: **per Claude Code turn** while a Claude Code session is open. When Claude Code is closed, the menu bar holds the last value; only the "resets in Xh Ym" countdown ticks down.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ with the license accepted (`sudo xcodebuild -license`) and first-launch setup done (`sudo xcodebuild -runFirstLaunch`)
- An Apple ID signed into Xcode → Settings → Accounts (the free Personal Team is fine — App Group entitlement only needs a development certificate, not a paid Developer Program)
- `jq`, `xcodegen` — `brew install jq xcodegen`

## Build

The project ships with the original author's `DEVELOPMENT_TEAM` baked in. The bootstrap script auto-detects yours, patches `project.yml`, and regenerates the Xcode project. Run it once after cloning:

```bash
./scripts/setup.sh
```

Then either:

```bash
open ClaudeWidget.xcodeproj   # ⌘R in Xcode
# or
xcodebuild -project ClaudeWidget.xcodeproj -scheme ClaudeWidget \
           -configuration Debug -destination 'platform=macOS' build
```

The script is idempotent — re-running on an already-configured checkout just regenerates the project.

**Bundle-ID conflicts.** Apple's developer portal reserves explicit App IDs and App Group IDs *globally across teams*. If signing fails with "App ID 'com.icaro.claudewidget' is not available", edit `project.yml` and replace the prefix:

```bash
sed -i '' 's/com\.icaro\.claudewidget/com.YOURNAME.claudewidget/g' project.yml
sed -i '' 's/group\.icaro\.claudewidget/group.YOURNAME.claudewidget/g' \
    project.yml \
    ClaudeWidget/Resources/ClaudeWidget.entitlements \
    ClaudeWidgetExtension/ClaudeWidgetExtension.entitlements \
    ClaudeWidget/Store/AppGroup.swift \
    ClaudeWidgetExtension/SharedTypes.swift \
    scripts/capture.sh
./scripts/setup.sh
```

(The App Group ID is referenced from both Swift sources and the capture script — that's why it appears in six places.)

## Wire up the statusLine pipe

The build produces `ClaudeWidget.app` somewhere under `~/Library/Developer/Xcode/DerivedData/...`. Drag it to `/Applications` once you're happy.

The app starts empty until Claude Code starts emitting data. Two steps to plug in the data source:

```bash
# 1. Install the capture script
mkdir -p ~/.claude/widget
cp scripts/capture.sh ~/.claude/widget/capture.sh
chmod +x ~/.claude/widget/capture.sh
```

2. Add a `statusLine` block to `~/.claude/settings.json`. Either edit the file by hand and add the top-level key:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/widget/capture.sh"
}
```

…or do it with `jq` (preserves all your other settings):

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq '. + {statusLine: {type: "command", command: "~/.claude/widget/capture.sh"}}' \
    ~/.claude/settings.json.bak > ~/.claude/settings.json
```

If you already have a `statusLine` configured, **don't blindly replace it** — see "Chaining" below.

## Run it

1. Run the app (`⌘R` in Xcode, or `open ClaudeWidget.app`). The menu-bar item appears.
2. Open a fresh Claude Code session (`claude` in any terminal). Existing sessions don't re-read `settings.json`.
3. Send any prompt. After the response, the menu bar should populate (e.g. `34% · 3%w`).
4. Right-click the desktop → **Edit Widgets** → search for "Claude Usage" → drag any size onto the desktop.

## Verifying the data with the debug script

If you want to inspect the raw JSON Claude Code is feeding the pipe — useful for understanding exactly which `rate_limits` keys your plan emits — temporarily swap in `capture-debug.sh`:

```bash
cp scripts/capture-debug.sh ~/.claude/widget/capture-debug.sh
chmod +x ~/.claude/widget/capture-debug.sh
jq '.statusLine.command = "~/.claude/widget/capture-debug.sh"' \
    ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json
```

Run a few turns in a fresh Claude Code session, then:

```bash
tail -1 ~/.claudewidget-debug.log | jq -r '.raw' | jq '.rate_limits | keys'
```

You should see `["five_hour", "seven_day"]`. Switch back to `capture.sh` once you're done and remove `~/.claudewidget-debug.log`.

## Chaining with an existing statusLine

If you already use `statusLine` for a TUI status string, wrap rather than replace. Make `~/.claude/widget/capture.sh` a tee plus a passthrough:

```bash
#!/bin/bash
INPUT=$(cat)

# Tee for the widget
TARGET="$HOME/Library/Group Containers/group.icaro.claudewidget"
mkdir -p "$TARGET"
printf '%s' "$INPUT" | jq -c '.rate_limits // {}' > "$TARGET/latest.json.tmp"
mv "$TARGET/latest.json.tmp" "$TARGET/latest.json"

# Whatever your old statusLine command does
printf '%s' "$INPUT" | <your-existing-status-line-command>
```

`capture.sh` writes nothing to stdout by default, so the original handler can produce the actual TUI text without conflict.

## Troubleshooting

**Menu bar shows `—% · —%w` and never updates.**
The capture script isn't running. Check, in order:

1. `ls -l ~/.claude/widget/capture.sh` — exists, executable.
2. `jq .statusLine ~/.claude/settings.json` — points at it.
3. `ls "$HOME/Library/Group Containers/group.icaro.claudewidget/latest.json"` — was the file ever written?
4. Did you start a *new* Claude Code session after editing `settings.json`? Existing sessions don't pick up the change.

**Menu bar shows only the first percentage.**
Old build. The fix went into `MenuBarLabel.swift` after the initial release — pull and rebuild.

**"Settings" button in the popover does nothing.**
Same as above — the activation fix lives in `ClaudeWidgetApp.swift`. Rebuild.

**Build fails with "entitlements that require signing with a development certificate".**
Either no Apple ID is signed into Xcode (`Xcode → Settings → Accounts → +`), or `DEVELOPMENT_TEAM` in `project.yml` doesn't match an identity in your keychain. Run `security find-identity -p codesigning -v` and update `project.yml`.

**Build fails with "bundle identifier is not prefixed with the parent app's bundle identifier".**
Stale `Info.plist` or pbxproj. Run `xcodegen generate` again.

**The "Sonnet only" line never appears.**
By design — the `statusLine` JSON doesn't include `seven_day_sonnet`, even on Enterprise plans. The widget hides any window that's missing.

**Widget on the desktop shows placeholder data forever.**
Until the App's `RateLimitsStore` reloads, the Widget Extension reads the same App Group file. If the menu bar is showing real data and the desktop widget isn't, remove and re-add the widget — the Widget Extension occasionally caches the placeholder timeline through reinstalls.

## Project layout

```
.
├── project.yml                          xcodegen spec — single source of truth
├── scripts/
│   ├── capture.sh                       production statusLine handler
│   └── capture-debug.sh                 raw-JSON dumper for verification
├── ClaudeWidget/                        macOS app target
│   ├── ClaudeWidgetApp.swift            entry point + scenes
│   ├── Models/
│   │   ├── RateLimits.swift             Codable models
│   │   └── Threshold.swift              color + countdown helpers
│   ├── Store/
│   │   ├── AppGroup.swift               shared paths
│   │   └── RateLimitsStore.swift        FSEvents watcher + WidgetCenter trigger
│   ├── Views/
│   │   ├── MenuBarLabel.swift           compact menu-bar text
│   │   ├── RateRowView.swift            one row of label/percent/bar
│   │   ├── PopoverView.swift            full menu-bar popover
│   │   └── SettingsView.swift           health UI window
│   └── Resources/
│       └── ClaudeWidget.entitlements    App Group + sandbox
└── ClaudeWidgetExtension/               Widget Extension target
    ├── ClaudeWidgetExtensionBundle.swift
    ├── ClaudeWidgetEntry.swift
    ├── ClaudeWidgetProvider.swift
    ├── ClaudeWidgetView.swift           three widget families
    ├── SharedTypes.swift                independent copies (target sandbox)
    ├── Info.plist                       NSExtension dict
    └── ClaudeWidgetExtension.entitlements
```

## Out of scope (V1)

- Notarization / `.dmg` distribution
- Push notifications when crossing thresholds
- Historical charts
- Cost tracking — `$0.0000` on subscription plans
- Auto-install of the capture script
- Sonnet-only weekly cap (not exposed by `statusLine`)
- Opus-only weekly cap (the binary contains a `seven_day_opus` reference but it isn't emitted to subscribers' statusLine — easy to add when it lands)
