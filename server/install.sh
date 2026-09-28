#!/bin/bash
# Install or update the Hyperday push server on a Raspberry Pi (Raspberry Pi OS / Debian).
# Run on the Pi from this folder:  sudo ./install.sh
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }

APP=/opt/hyperday-push
DATA=/var/lib/hyperday-push
ENVF=/etc/hyperday-push.env

id hyperday >/dev/null 2>&1 || useradd --system --home "$DATA" --shell /usr/sbin/nologin hyperday
mkdir -p "$APP" "$DATA"
cp -r hyperday_push requirements.txt "$APP/"
apt-get install -y -qq python3-venv >/dev/null
[[ -d "$APP/.venv" ]] || python3 -m venv "$APP/.venv"
"$APP/.venv/bin/pip" install -q --upgrade pip
"$APP/.venv/bin/pip" install -q -r "$APP/requirements.txt"
chown -R hyperday:hyperday "$DATA"

if [[ ! -f "$ENVF" ]]; then
  TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
  cat > "$ENVF" <<ENV
# Hyperday push server settings. Restart after editing: sudo systemctl restart hyperday-push
HYPERDAY_AUTH_TOKEN=$TOKEN
HYPERDAY_DB=$DATA/hyperday-push.db

# Fill these in after joining the Apple Developer Program (until then it runs in dry-run mode):
APNS_TEAM_ID=
APNS_KEY_ID=
APNS_KEY_PATH=$DATA/AuthKey.p8
APNS_ENV=sandbox
ENV
  chmod 600 "$ENVF"
  echo "› Created $ENVF"
fi

cp hyperday-push.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now hyperday-push
systemctl restart hyperday-push
sleep 2
curl -fsS http://127.0.0.1:8787/health && echo

if command -v tailscale >/dev/null; then
  tailscale serve --bg 8787 >/dev/null && echo "› Published on your tailnet:" && tailscale serve status | head -3
else
  echo "! Tailscale isn't installed. Install it: curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up"
  echo "  then run: sudo tailscale serve --bg 8787"
fi
echo
echo "Token for the Hyperday app (Settings › On-time switching):"
grep HYPERDAY_AUTH_TOKEN "$ENVF" | cut -d= -f2
