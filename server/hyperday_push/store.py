import json
import sqlite3
import threading
import time
from typing import Any, Optional

SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
    device_id      TEXT PRIMARY KEY,
    activity_token TEXT,            -- update token of the running Live Activity
    start_token    TEXT,            -- push-to-start token (iOS 17.2+)
    updated_at     REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS events (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    fire_at   REAL NOT NULL,        -- unix seconds
    kind      TEXT NOT NULL,        -- start | update | end
    payload   TEXT NOT NULL,        -- JSON: content_state, stale_date, dismissal_date, attributes
    sent_at   REAL,
    status    TEXT                  -- sent | dry-run | skipped-late | no-token | error:<reason>
);
CREATE INDEX IF NOT EXISTS events_due ON events (sent_at, fire_at);
"""


class Store:
    """Tiny SQLite store. One writer (this process), so a lock is enough."""

    def __init__(self, path: str):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
        self.lock = threading.Lock()

    def set_tokens(self, device_id: str, activity_token: Optional[str], start_token: Optional[str]) -> None:
        with self.lock, self.db:
            row = self.db.execute("SELECT * FROM devices WHERE device_id=?", (device_id,)).fetchone()
            a = activity_token if activity_token is not None else (row["activity_token"] if row else None)
            s = start_token if start_token is not None else (row["start_token"] if row else None)
            self.db.execute(
                "INSERT OR REPLACE INTO devices (device_id, activity_token, start_token, updated_at) VALUES (?,?,?,?)",
                (device_id, a or None, s or None, time.time()),
            )

    def clear_token(self, device_id: str, which: str) -> None:
        assert which in ("activity_token", "start_token")
        with self.lock, self.db:
            self.db.execute(f"UPDATE devices SET {which}=NULL WHERE device_id=?", (device_id,))

    def device(self, device_id: str) -> Optional[sqlite3.Row]:
        with self.lock:
            return self.db.execute("SELECT * FROM devices WHERE device_id=?", (device_id,)).fetchone()

    def replace_schedule(self, device_id: str, events: list[dict[str, Any]]) -> int:
        """Drop this device's unsent events and store the new plan. The phone always sends the whole rest of the day."""
        with self.lock, self.db:
            self.db.execute("DELETE FROM events WHERE device_id=? AND sent_at IS NULL", (device_id,))
            self.db.executemany(
                "INSERT INTO events (device_id, fire_at, kind, payload) VALUES (?,?,?,?)",
                [(device_id, e["at"], e["kind"], json.dumps(e["payload"])) for e in events],
            )
        return len(events)

    def due(self, now: float) -> list[sqlite3.Row]:
        with self.lock:
            return self.db.execute(
                "SELECT * FROM events WHERE sent_at IS NULL AND fire_at <= ? ORDER BY fire_at", (now,)
            ).fetchall()

    def mark(self, event_id: int, status: str, now: float) -> None:
        with self.lock, self.db:
            self.db.execute("UPDATE events SET sent_at=?, status=? WHERE id=?", (now, status, event_id))

    def pending(self, device_id: Optional[str] = None) -> list[sqlite3.Row]:
        q = "SELECT * FROM events WHERE sent_at IS NULL" + (" AND device_id=?" if device_id else "") + " ORDER BY fire_at"
        with self.lock:
            return self.db.execute(q, (device_id,) if device_id else ()).fetchall()

    def recent(self, limit: int = 20) -> list[sqlite3.Row]:
        with self.lock:
            return self.db.execute(
                "SELECT * FROM events WHERE sent_at IS NOT NULL ORDER BY sent_at DESC LIMIT ?", (limit,)
            ).fetchall()

    def prune(self, older_than: float) -> None:
        with self.lock, self.db:
            self.db.execute("DELETE FROM events WHERE sent_at IS NOT NULL AND sent_at < ?", (older_than,))
