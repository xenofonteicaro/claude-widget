#!/bin/bash
# One-time bootstrap for first-time builders.
#
# - Detects the Apple Development team ID from the keychain (using the X.509
#   `OU=` field, which is the authoritative source — the parenthesized hash in
#   the cert's CN is NOT a team ID, despite looking like one).
# - Patches project.yml with that team ID.
# - Runs xcodegen.
#
# After this you can either open AIUsageWidget.xcodeproj in Xcode (⌘R) or run
# xcodebuild from the CLI.

set -euo pipefail

cd "$(dirname "$0")/.."

# --- 0. Required tools

for tool in xcodegen security openssl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing tool: $tool"
    echo "  brew install xcodegen jq"
    exit 1
  fi
done

# --- 1. Find a usable signing identity

CERT_PEM=$(security find-certificate -c "Apple Development:" -p 2>/dev/null || true)

if [ -z "$CERT_PEM" ]; then
  cat <<EOF
No "Apple Development" certificate found in your login keychain.

Open Xcode → Settings → Accounts → "+" → Apple ID and sign in. Xcode will
provision a Personal Team and add the cert to your keychain. Then re-run
this script.

(A free Apple ID is enough — App Group entitlement only needs a
development cert, not a paid Developer Program membership.)
EOF
  exit 1
fi

TEAM_ID=$(echo "$CERT_PEM" \
  | openssl x509 -noout -subject 2>/dev/null \
  | grep -oE 'OU=[A-Z0-9]{10}' \
  | head -1 \
  | cut -d= -f2 \
  || true)

if [ -z "$TEAM_ID" ]; then
  echo "Found a development cert but couldn't extract the team ID from its OU field."
  echo "Please pass it manually: open Xcode → Settings → Accounts → highlight your"
  echo "Apple ID → Team ID is the 10-character code in the right column."
  echo
  read -rp "Team ID: " TEAM_ID
fi

if ! [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Refusing to use \"$TEAM_ID\" — Apple team IDs are 10 uppercase alphanumerics."
  exit 1
fi

echo "Team ID: $TEAM_ID"

# --- 2. Patch project.yml

CURRENT=$(grep -E '^    DEVELOPMENT_TEAM:' project.yml | head -1 | awk '{print $2}' || true)

if [ "$CURRENT" = "$TEAM_ID" ]; then
  echo "project.yml already configured for this team."
else
  sed -i.bak -E "s|^(    DEVELOPMENT_TEAM:).*|\\1 $TEAM_ID|" project.yml
  rm -f project.yml.bak
  echo "Patched project.yml: DEVELOPMENT_TEAM = $TEAM_ID"
fi

# --- 3. Generate

xcodegen generate >/dev/null
echo "Generated AIUsageWidget.xcodeproj"

cat <<EOF

Done. Next:

  open AIUsageWidget.xcodeproj   # then ⌘R in Xcode
  # or
  xcodebuild -project AIUsageWidget.xcodeproj -scheme AIUsageWidget \\
             -configuration Debug -destination 'platform=macOS' build

If Xcode complains about a bundle-ID conflict ("App ID 'com.icaro.aiusagewidget'
is not available"), it's because that ID is already registered to a different
team in Apple's portal. Edit project.yml and change occurrences of
"com.icaro.aiusagewidget" to a unique reverse-DNS prefix, then re-run this
script.

Once built, install the shared capture script for Claude Code:

  mkdir -p ~/.claude/widget
  cp scripts/capture.sh ~/.claude/widget/capture.sh
  chmod +x ~/.claude/widget/capture.sh
  jq '. + {statusLine: {type: "command", command: "~/.claude/widget/capture.sh"}}' \\
      ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json

Then start a new Claude Code session. Existing sessions do not re-read settings.

To feed Codex hook payloads into the same widget, add the capture command to
~/.codex/hooks.json. Codex passes hook JSON as the first argument, and this
script supports that form:

  mkdir -p ~/.codex/widget
  cp scripts/capture.sh ~/.codex/widget/capture.sh
  chmod +x ~/.codex/widget/capture.sh

Use the README for a complete hooks.json example. The menu bar will populate
after Codex emits a hook payload containing supported usage-limit fields.
EOF
