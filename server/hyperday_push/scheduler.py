import asyncio
import json
import logging
import time

from .apns import APNs, build_payload
from .config import Config
from .store import Store

log = logging.getLogger("hyperday.scheduler")


async def run_due(store: Store, apns: APNs, cfg: Config, now: float) -> list[tuple[int, str]]:
    """Send every event whose time has come. Returns (event id, status) for logging and tests."""
    results = []
    for ev in store.due(now):
        if now - ev["fire_at"] > cfg.late_limit and ev["kind"] != "end":
            status = "skipped-late"
        else:
            dev = store.device(ev["device_id"])
            which = "start_token" if ev["kind"] == "start" else "activity_token"
            token = dev[which] if dev else None
            if not token:
                status = "no-token"
            else:
                payload = build_payload(ev["kind"], json.loads(ev["payload"]), now)
                try:
                    code, reason = await apns.send(token, payload)
                except Exception as e:  # network down, DNS, etc. Try again next tick unless it's late by then.
                    log.warning("send failed: %s", e)
                    continue
                if code == 200:
                    status = "dry-run" if reason == "dry-run" else "sent"
                else:
                    status = f"error:{code}:{reason}"
                    if code == 410 or reason in ("BadDeviceToken", "Unregistered", "ExpiredToken"):
                        store.clear_token(ev["device_id"], which)   # activity ended; the phone sends a new one
        store.mark(ev["id"], status, now)
        results.append((ev["id"], status))
        log.info("event %s %s at %s -> %s", ev["id"], ev["kind"], int(ev["fire_at"]), status)
    return results


async def loop(store: Store, apns: APNs, cfg: Config, every: float = 5.0) -> None:
    last_prune = 0.0
    while True:
        now = time.time()
        try:
            await run_due(store, apns, cfg, now)
            if now - last_prune > 3600:
                store.prune(now - 7 * 86400)
                last_prune = now
        except Exception:
            log.exception("scheduler tick failed")
        await asyncio.sleep(every)
