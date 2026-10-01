#!/bin/zsh
# Build Hyperday and install it on your connected iPhone (cable or same Wi-Fi).
# Usage:  cd ~/Downloads/DayLive && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

# Your signing team. Regenerating the project wipes the Team picked in Xcode,
# so detect it from your Apple Development certificate (or set DEVELOPMENT_TEAM yourself).
if [[ -z "${DEVELOPMENT_TEAM:-}" && -f .team ]]; then DEVELOPMENT_TEAM=$(<.team); fi
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  DEVELOPMENT_TEAM=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)
fi
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "✗ Couldn't find your signing team. In Xcode: Settings › Accounts › your Apple ID › Personal Team,"
  echo "  then run:  DEVELOPMENT_TEAM=<10-character ID> ./deploy.sh"
  exit 1
fi
echo "$DEVELOPMENT_TEAM" > .team
export DEVELOPMENT_TEAM
echo "› Team $DEVELOPMENT_TEAM"

echo "› Generating Xcode project…"
xcodegen generate --quiet

# Home Screen widgets share data through an App Group, which needs the paid Apple Developer Program.
# Try with it first; if signing refuses (free Apple ID), build without it and remember that in .no-app-group.
build() {
  xcodebuild -project DayLive.xcodeproj -scheme DayLive -configuration Debug \
    -destination 'generic/platform=iOS' -derivedDataPath build \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
    "$@" -quiet build
}

echo "› Building…"
LOG=$(mktemp)
if [[ -f .no-app-group || -n "${NO_APP_GROUP:-}" ]]; then
  build
elif ! build CODE_SIGN_ENTITLEMENTS=Hyperday.entitlements 2>&1 | tee "$LOG"; then   # pipefail: xcodebuild's status
  if grep -qiE "app group|application-groups|Personal development teams" "$LOG"; then
    echo "› Your Apple ID can't use App Groups (free account). Building without Home Screen widgets…"
    touch .no-app-group
    build
  else
    rm -f "$LOG"; exit 1
  fi
fi
rm -f "$LOG"

APP=build/Build/Products/Debug-iphoneos/DayLive.app

echo "› Finding your iPhone…"
JSON=$(mktemp)
xcrun devicectl list devices --json-output "$JSON" >/dev/null
DEVICE=$(/usr/bin/python3 - "$JSON" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
phones = [d for d in devices
          if d.get("hardwareProperties", {}).get("platform") == "iOS"
          and d.get("hardwareProperties", {}).get("reality") == "physical"   # skip simulators
          and d.get("connectionProperties", {}).get("pairingState") == "paired"
          and d.get("connectionProperties", {}).get("tunnelState") != "unavailable"]
# Prefer a phone that's connected right now (cable or Wi-Fi) over one that's merely paired.
phones.sort(key=lambda d: d.get("connectionProperties", {}).get("tunnelState") != "connected")
print(phones[0]["identifier"] if phones else "")
PY
)
rm -f "$JSON"
if [[ -z "$DEVICE" ]]; then
  echo "✗ No iPhone found. Unlock it and connect by cable or the same Wi-Fi, then try again."
  exit 1
fi

echo "› Installing…"
xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null
xcrun devicectl device process launch --device "$DEVICE" com.prabhu.daylive >/dev/null || true
echo "✓ Hyperday is on your iPhone."
