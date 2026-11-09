#!/bin/bash
# Usage: ui-screenshots.sh <path to Feather.app> <output folder> <iPad|iPhone>
set -uo pipefail

APP="$1"
OUT="$2"
KIND="$3"
BUNDLE="dev.madebynuz.dev.feather"
mkdir -p "$OUT"

pick_device_type() {
	xcrun simctl list devicetypes -j | python3 -c '
import json, sys
kind = sys.argv[1]
types = json.load(sys.stdin)["devicetypes"]
wanted = ["iPad Pro 13", "iPad Pro"] if kind == "iPad" else ["iPhone 17 Pro", "iPhone 16 Pro", "iPhone"]
for name in wanted:
    matches = [t for t in types if name in t["name"]]
    if matches:
        print(matches[-1]["identifier"]); break
' "$KIND"
}

RUNTIME="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
print(runtimes[-1]["identifier"])
')"
DEVICE_TYPE="$(pick_device_type)"
echo "Using $DEVICE_TYPE on $RUNTIME"

UDID="$(xcrun simctl create "Feather $KIND" "$DEVICE_TYPE" "$RUNTIME")"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 || true

xcrun simctl install "$UDID" "$APP"

# Skip onboarding and keep one GitHub repository in Sources so that screen has content.
# Preferences are written through the simulator's own defaults so the app sees them.
DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
PREFS="$DATA/Library/Preferences/$BUNDLE"
LABEL="$(/usr/libexec/PlistBuddy -c 'Print :FeatherVersionLabel' "$APP/Info.plist" 2>/dev/null || echo none)"
GITHUB_HEX="$(printf '%s' '[{"owner":"LiveContainer","name":"LiveContainer"}]' | xxd -p | tr -d '\n')"
xcrun simctl spawn "$UDID" defaults write "$PREFS" Onboarding.seen -bool YES
xcrun simctl spawn "$UDID" defaults write "$PREFS" WhatsNew.seenVersion -string "$LABEL"
xcrun simctl spawn "$UDID" defaults write "$PREFS" GitHub.sources -data "$GITHUB_HEX"

STEP=0
LANDSCAPE=0
shot() {
	STEP=$((STEP + 1))
	local name
	name="$(printf '%02d' "$STEP")-$1"
	sleep 1.5
	xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1 || echo "Screenshot failed: $name"
	if [ "$LANDSCAPE" = "1" ]; then sips -r 270 "$OUT/$name.png" >/dev/null 2>&1 || true; fi
	axe describe-ui --udid "$UDID" > "$OUT/$name.txt" 2>&1 || true
	echo "Captured $name"
}
tap() {
	if axe tap --label "$1" --udid "$UDID" >/dev/null 2>&1; then
		sleep 2
	else
		echo "Couldn't tap \"$1\""
		axe describe-ui --udid "$UDID" > "$OUT/failed-tap-$(echo "$1" | tr -c 'A-Za-z0-9' '_').txt" 2>&1 || true
	fi
}
add_source() {
	tap "Add"
	tap "Enter Source URL"
	axe type "$1" --udid "$UDID" >/dev/null 2>&1 || echo "Couldn't type the source URL"
	sleep 1
	tap "Save"
	sleep 5
}
rotate() {
	osascript -e 'tell application "Simulator" to activate' \
		-e "tell application \"System Events\" to key code $1 using command down" >/dev/null 2>&1 \
		|| echo "Couldn't rotate"
	sleep 3
}
crashed() {
	! xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q "$BUNDLE"
}

xcrun simctl launch "$UDID" "$BUNDLE"
sleep 8
tap "Skip"
add_source "https://raw.githubusercontent.com/NuzProjects/Feather/refs/heads/main/source.json"
add_source "https://raw.githubusercontent.com/Aidoku/Aidoku/altstore/apps.json"
sleep 3

shot sources
tap "All Repositories"; shot all-apps
tap "Sources"
tap "Feather (NuzProjects)"; shot source
tap "Feather"; shot app-page
tap "Sources"; tap "Sources"
tap "LiveContainer"; sleep 4; shot github-source
tap "Sources"
tap "Library"; shot library
tap "Settings"; shot settings
tap "Appearance"; shot settings-appearance
tap "Settings"
tap "Updates"; shot settings-updates
tap "Settings"
tap "Installation"; shot settings-installation
tap "Settings"

if [ "$KIND" = "iPad" ]; then
	rotate 123
	LANDSCAPE=1
	shot settings-landscape
	tap "Sources"; shot sources-landscape
	tap "Feather (NuzProjects)"; shot source-landscape
	rotate 124
	LANDSCAPE=0
fi

xcrun simctl spawn "$UDID" log show --last 10m --predicate "process == \"Feather\" AND messageType == fault" --style compact > "$OUT/faults.log" 2>/dev/null || true
if crashed; then
	echo "Feather is no longer running on the $KIND simulator" | tee "$OUT/CRASHED.txt"
fi
xcrun simctl shutdown "$UDID" || true
