#!/bin/zsh
# Build Hyperday and install it on your connected iPhone (cable or same Wi-Fi).
# Usage:  cd ~/Downloads/DayLive && ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "› Generating Xcode project…"
xcodegen generate --quiet

echo "› Building…"
xcodebuild -project DayLive.xcodeproj -scheme DayLive -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -quiet build

APP=build/Build/Products/Debug-iphoneos/DayLive.app

echo "› Finding your iPhone…"
JSON=$(mktemp)
xcrun devicectl list devices --json-output "$JSON" >/dev/null
DEVICE=$(/usr/bin/python3 - "$JSON" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
phones = [d for d in devices
          if d.get("hardwareProperties", {}).get("platform") == "iOS"
          and d.get("connectionProperties", {}).get("pairingState") == "paired"
          and d.get("connectionProperties", {}).get("tunnelState") != "unavailable"]
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
