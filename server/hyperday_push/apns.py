import logging
import time
from typing import Any, Optional

import httpx
import jwt

from .config import Config

log = logging.getLogger("hyperday.apns")


def build_payload(kind: str, data: dict[str, Any], now: float) -> dict[str, Any]:
    """APNs Live Activity payload. content_state is exactly what the app encoded, so ActivityKit decodes it as-is."""
    aps: dict[str, Any] = {"timestamp": int(now), "event": kind, "content-state": data["content_state"]}
    if data.get("stale_date"):
        aps["stale-date"] = int(data["stale_date"])
    if kind == "end" and data.get("dismissal_date"):
        aps["dismissal-date"] = int(data["dismissal_date"])
    if kind == "start":
        aps["attributes-type"] = "DayActivityAttributes"
        aps["attributes"] = data.get("attributes", {})
        aps["alert"] = {"title": "Hyperday", "body": data.get("alert", "Your day is live.")}
    return {"aps": aps}


class APNs:
    def __init__(self, cfg: Config, client: Optional[httpx.AsyncClient] = None):
        self.cfg = cfg
        self.client = client
        self._jwt: Optional[str] = None
        self._jwt_at = 0.0

    def _token(self) -> str:
        # Apple accepts a provider token for up to 60 minutes and rejects refreshing more than every 20.
        if not self._jwt or time.time() - self._jwt_at > 50 * 60:
            key = open(self.cfg.key_path).read()
            self._jwt = jwt.encode({"iss": self.cfg.team_id, "iat": int(time.time())}, key,
                                   algorithm="ES256", headers={"kid": self.cfg.key_id})
            self._jwt_at = time.time()
        return self._jwt

    async def send(self, device_token: str, payload: dict[str, Any], priority: int = 10) -> tuple[int, str]:
        if self.cfg.dry_run:
            log.info("dry-run push to %s…: %s", device_token[:8], payload["aps"].get("event"))
            return 200, "dry-run"
        if self.client is None:
            self.client = httpx.AsyncClient(http2=True, timeout=15)
        r = await self.client.post(
            f"{self.cfg.apns_host}/3/device/{device_token}",
            json=payload,
            headers={
                "authorization": f"bearer {self._token()}",
                "apns-topic": f"{self.cfg.bundle_id}.push-type.liveactivity",
                "apns-push-type": "liveactivity",
                "apns-priority": str(priority),
            },
        )
        reason = "" if r.status_code == 200 else (r.json().get("reason", r.text) if r.content else "")
        return r.status_code, reason or "ok"
