#!/bin/zsh
# Rebuilds, re-signs (free Apple ID) and reinstalls The Wilderness on the Apple TV.
# Free provisioning expires after 7 days; launchd runs this daily so a missed night never
# lets it lapse. Saved calibration on the Apple TV is kept across reinstalls.
# It builds for the specific Apple TV: a free team can only make a provisioning profile for a
# device it has registered, and building for that device is what registers it.
#
# Needs scripts/refresh.conf with:
#   TEAM_ID=XXXXXXXXXX        # Xcode → Settings → Accounts → your Personal Team ID
#   DEVICE_ID=XXXXXXXX-...    # from: xcrun devicectl list devices
set -u
ROOT="${0:A:h:h}"
LOG="$HOME/Library/Logs/Wilderness-refresh.log"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

notify_fail() {
  echo "$(date '+%F %T') FAILED: $1" >> "$LOG"
  osascript -e "display notification \"$1\" with title \"Wilderness refresh failed\"" 2>/dev/null
  exit 1
}

[[ -f "$ROOT/scripts/refresh.conf" ]] || notify_fail "missing scripts/refresh.conf"
source "$ROOT/scripts/refresh.conf"
[[ -n "${TEAM_ID:-}" && -n "${DEVICE_ID:-}" ]] || notify_fail "TEAM_ID or DEVICE_ID not set"

echo "$(date '+%F %T') start" >> "$LOG"
xcodebuild -project "$ROOT/Wilderness.xcodeproj" -scheme Wilderness -configuration Release \
  -destination "id=$DEVICE_ID" -derivedDataPath "$ROOT/build" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
  build >> "$LOG" 2>&1 || notify_fail "build/sign step (see $LOG)"

APP="$ROOT/build/Build/Products/Release-appletvos/Wilderness.app"
[[ -d "$APP" ]] || notify_fail "built app not found at $APP"

xcrun devicectl device install app --device "$DEVICE_ID" "$APP" >> "$LOG" 2>&1 \
  || notify_fail "install on Apple TV (is it on the same Wi-Fi and paired?)"

echo "$(date '+%F %T') OK: installed fresh build" >> "$LOG"
