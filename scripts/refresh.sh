#!/bin/zsh
# Rebuilds, re-signs (free Apple ID) and reinstalls The Wilderness on the Apple TV.
# Free provisioning expires after 7 days. launchd calls this every afternoon, but it only
# installs between 2 pm and 10 pm and when the last good install is 6+ days old
# (scripts/refresh_due.py): about once a week, never at night (Matt, 2026-11-15).
# If the Apple TV was off before the install, it is put back to sleep afterwards (needs pyatv's
# atvremote in ~/.local/share/wilderness-atv/venv, paired once, and ATV_NAME in refresh.conf). Saved calibration is kept across reinstalls.
# It builds for the specific Apple TV: a free team can only make a provisioning profile for a
# device it has registered, and building for that device is what registers it.
#
# Needs scripts/refresh.conf with:
#   TEAM_ID=XXXXXXXXXX        # Xcode → Settings → Accounts → your Personal Team ID
#   DEVICE_ID=XXXXXXXX-...    # from: xcrun devicectl list devices
#   PHONE_ID=...              # optional: the iPhone for the companion app (same list)
#   APIBIBLE_KEY=...          # api.bible key; with NIV_BIBLE_ID and NLT_BIBLE_ID, the licensed
#                             # verses are re-fetched before each build (scripts/fetch_verses.py)
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

STAMP="$HOME/Library/Logs/Wilderness-last-ok"
/usr/bin/python3 -I "$ROOT/scripts/refresh_due.py" "$STAMP" || exit 0   # not due, or outside the evening window

# Was the Apple TV asleep? Then it goes back to sleep after the install.
WAS_OFF=0
ATV="$HOME/.local/share/wilderness-atv/venv/bin/atvremote"   # pyatv, in its own venv (Python 3.12)
if [[ -n "${ATV_NAME:-}" && -x "$ATV" ]]; then
  "$ATV" -n "$ATV_NAME" power_state 2>/dev/null | grep -q "Off" && WAS_OFF=1
fi

echo "$(date '+%F %T') start" >> "$LOG"
# Licensed verse text must be re-fetched at least every 30 days (API.Bible); a failure keeps
# the last good copy for up to 30 days, so it warns but never stops the build.
/usr/bin/python3 -I "$ROOT/scripts/fetch_verses.py" >> "$LOG" 2>&1 \
  || osascript -e 'display notification "Verse fetch failed; see the refresh log" with title "Wilderness refresh"' 2>/dev/null
xcodebuild -project "$ROOT/Wilderness.xcodeproj" -scheme Wilderness -configuration Release \
  -destination "id=$DEVICE_ID" -derivedDataPath "$ROOT/build" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
  build >> "$LOG" 2>&1 || notify_fail "build/sign step (see $LOG)"

APP="$ROOT/build/Build/Products/Release-appletvos/Wilderness.app"
[[ -d "$APP" ]] || notify_fail "built app not found at $APP"

xcrun devicectl device install app --device "$DEVICE_ID" "$APP" >> "$LOG" 2>&1 \
  || notify_fail "install on Apple TV (is it on the same Wi-Fi and paired?)"

echo "$(date '+%F %T') OK: installed fresh build" >> "$LOG"
date '+%Y-%m-%dT%H:%M:%S' > "$STAMP"

# The iPhone companion (optional): re-signed and installed when PHONE_ID is set and the phone is
# reachable (awake, unlocked, same Wi-Fi). A missing phone only warns; the Apple TV is what matters.
if [[ -n "${PHONE_ID:-}" ]]; then
  if xcodebuild -project "$ROOT/Wilderness.xcodeproj" -scheme WildernessPhone -configuration Release \
       -destination "id=$PHONE_ID" -derivedDataPath "$ROOT/build" \
       -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
       build >> "$LOG" 2>&1 \
     && xcrun devicectl device install app --device "$PHONE_ID" \
          "$ROOT/build/Build/Products/Release-iphoneos/WildernessPhone.app" >> "$LOG" 2>&1; then
    echo "$(date '+%F %T') OK: installed iPhone companion" >> "$LOG"
  else
    echo "$(date '+%F %T') WARN: iPhone companion not installed (phone asleep, locked or away?)" >> "$LOG"
  fi
fi

if [[ "$WAS_OFF" == 1 ]]; then
  sleep 20   # let the install settle
  "$ATV" -n "$ATV_NAME" turn_off >> "$LOG" 2>&1 \
    && echo "$(date '+%F %T') OK: Apple TV back to sleep" >> "$LOG" \
    || echo "$(date '+%F %T') WARN: could not put the Apple TV back to sleep" >> "$LOG"
fi
