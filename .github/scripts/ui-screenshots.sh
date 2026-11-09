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
# The simulator build has no bundled install certificate, so keep Feather from offering to switch server type.
xcrun simctl spawn "$UDID" defaults write "$PREFS" Feather.serverMethodSemiLocal -bool YES
xcrun simctl spawn "$UDID" defaults write "$PREFS" Feather.serverMethod -int 0

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
# Finds the centre of the first on-screen element whose label is (or starts with) the text,
# or of the first element of a type when called with "type:TextField".
locate() {
	axe describe-ui --udid "$UDID" 2>/dev/null | python3 -c '
import json, re, sys
wanted = sys.argv[1]
try:
    tree = json.load(sys.stdin)
except Exception:
    sys.exit(1)
def frame(node):
    numbers = re.findall(r"-?[0-9.]+", node.get("AXFrame") or "")
    return [float(n) for n in numbers] if len(numbers) == 4 else None
last = wanted.startswith("last:")
if last:
    wanted = wanted[5:]
def matches(node):
    if wanted.startswith("type:"):
        return node.get("type") == wanted[5:]
    label = node.get("AXLabel") or ""
    return label == wanted or label.startswith(wanted + ",")
found = []
def walk(node):
    if isinstance(node, list):
        for child in node:
            walk(child)
        return
    if not isinstance(node, dict):
        return
    box = frame(node)
    if matches(node) and box and box[2] > 0 and box[3] > 0:
        found.append(box)
    walk(node.get("children") or [])
walk(tree)
if not found:
    sys.exit(1)
box = found[-1] if last else found[0]
print(round(box[0] + box[2] / 2), round(box[1] + box[3] / 2))
' "$1"
}
tap() {
	local point
	if point="$(locate "$1")" && axe tap -x "${point% *}" -y "${point#* }" --udid "$UDID" >/dev/null 2>&1; then
		sleep 2
	else
		echo "Couldn't tap \"$1\""
		axe describe-ui --udid "$UDID" > "$OUT/failed-tap-$(echo "$1" | tr -c 'A-Za-z0-9' '_').txt" 2>&1 || true
	fi
}
add_source() {
	tap "Add"
	tap "last:type:TextField"
	axe type "$1" --udid "$UDID" >/dev/null 2>&1 || echo "Couldn't type the source URL"
	sleep 1
	tap "Save"
	sleep 6
}
rotate() {
	osascript -e 'tell application "Simulator" to activate' \
		-e "tell application \"System Events\" to key code $1 using command down" >/dev/null 2>&1 \
		|| echo "Couldn't rotate"
	sleep 3
}
CRASHES_BEFORE="$(ls ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -c '^Feather' || true)"
crashed() {
	[ "$(ls ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -c '^Feather' || true)" -gt "$CRASHES_BEFORE" ]
}

xcrun simctl launch "$UDID" "$BUNDLE"
sleep 8
tap "Not Now"
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
	echo "Feather crashed on the $KIND simulator" | tee "$OUT/CRASHED.txt"
	cp ~/Library/Logs/DiagnosticReports/Feather* "$OUT/" 2>/dev/null || true
fi
xcrun simctl shutdown "$UDID" || true
