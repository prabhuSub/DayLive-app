import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Config:
    auth_token: str                  # shared secret the iPhone sends as "Authorization: Bearer ..."
    team_id: str = ""                # Apple Developer Team ID (10 chars)
    key_id: str = ""                 # APNs auth key ID (10 chars)
    key_path: str = ""               # path to AuthKey_XXXXXXXXXX.p8
    bundle_id: str = "com.prabhu.daylive"
    apns_env: str = "sandbox"        # "sandbox" for deploy.sh (Debug) builds, "production" for TestFlight/App Store
    db_path: str = "hyperday-push.db"
    late_limit: int = 600            # skip an update more than this many seconds late (e.g. the Pi was off)

    @property
    def dry_run(self) -> bool:
        """No APNs key yet: log what would be sent instead of sending."""
        return not (self.team_id and self.key_id and self.key_path and Path(self.key_path).is_file())

    @property
    def apns_host(self) -> str:
        return "https://api.push.apple.com" if self.apns_env == "production" else "https://api.sandbox.push.apple.com"

    @classmethod
    def from_env(cls) -> "Config":
        token = os.environ.get("HYPERDAY_AUTH_TOKEN", "")
        if len(token) < 24:
            raise SystemExit("Set HYPERDAY_AUTH_TOKEN (at least 24 characters) in /etc/hyperday-push.env")
        return cls(
            auth_token=token,
            team_id=os.environ.get("APNS_TEAM_ID", ""),
            key_id=os.environ.get("APNS_KEY_ID", ""),
            key_path=os.environ.get("APNS_KEY_PATH", ""),
            bundle_id=os.environ.get("APNS_BUNDLE_ID", "com.prabhu.daylive"),
            apns_env=os.environ.get("APNS_ENV", "sandbox"),
            db_path=os.environ.get("HYPERDAY_DB", "hyperday-push.db"),
            late_limit=int(os.environ.get("HYPERDAY_LATE_LIMIT", "600")),
        )
