import asyncio
import json
import time

import pytest
from fastapi.testclient import TestClient

from hyperday_push.apns import build_payload
from hyperday_push.app import create_app
from hyperday_push.config import Config
from hyperday_push.scheduler import run_due

TOKEN = "t" * 32
H = {"Authorization": f"Bearer {TOKEN}"}
CS = {"title": "Deep Work", "label": "Next · Standup at 10:30 AM", "segments": [1, 0.4], "dayProgress": 0.38}


@pytest.fixture
def env(tmp_path):
    cfg = Config(auth_token=TOKEN, db_path=str(tmp_path / "t.db"))
    app = create_app(cfg, run_scheduler=False)
    return app, TestClient(app)


def test_health_is_dry_run_without_key(env):
    _, c = env
    r = c.get("/health").json()
    assert r["ok"] and r["dry_run"] is True


def test_auth_required(env):
    _, c = env
    assert c.post("/v1/schedule", json={"device_id": "abcd", "events": []}).status_code == 401
    assert c.post("/v1/schedule", json={"device_id": "abcd", "events": []},
                  headers={"Authorization": "Bearer nope"}).status_code == 401


def test_schedule_replaces_and_sends_due(env):
    app, c = env
    now = time.time()
    ev = lambda dt, kind="update": {"at": now + dt, "kind": kind, "content_state": CS, "stale_date": now + dt + 900}
    r = c.post("/v1/schedule", headers=H, json={"device_id": "iphone", "activity_token": "abc123",
                                                 "events": [ev(-5), ev(600), ev(1200)]})
    assert r.json()["scheduled"] == 3
    # A new plan from the phone replaces what hasn't been sent.
    c.post("/v1/schedule", headers=H, json={"device_id": "iphone", "events": [ev(-5), ev(900)]})
    assert len(app.state.store.pending()) == 2

    st = app.state
    res = asyncio.run(run_due(st.store, st.apns, st.cfg, now))
    assert [s for _, s in res] == ["dry-run"]
    assert len(st.store.pending()) == 1


def test_late_updates_skipped_but_end_still_sent(env):
    app, c = env
    now = time.time()
    c.post("/v1/schedule", headers=H, json={"device_id": "iphone", "activity_token": "abc", "events": [
        {"at": now - 3600, "kind": "update", "content_state": CS},
        {"at": now - 3600, "kind": "end", "content_state": CS},
    ]})
    st = app.state
    res = asyncio.run(run_due(st.store, st.apns, st.cfg, now))
    assert [s for _, s in res] == ["skipped-late", "dry-run"]


def test_start_needs_start_token(env):
    app, c = env
    now = time.time()
    c.post("/v1/schedule", headers=H, json={"device_id": "iphone", "activity_token": "abc", "events": [
        {"at": now, "kind": "start", "content_state": CS, "attributes": {"dayStart": 0}},
    ]})
    st = app.state
    assert [s for _, s in asyncio.run(run_due(st.store, st.apns, st.cfg, now))] == ["no-token"]


def test_payload_shape():
    now = 1_800_000_000
    p = build_payload("update", {"content_state": CS, "stale_date": now + 60}, now)["aps"]
    assert p == {"timestamp": now, "event": "update", "content-state": CS, "stale-date": now + 60}
    s = build_payload("start", {"content_state": CS, "attributes": {"dayStart": 1}}, now)["aps"]
    assert s["attributes-type"] == "DayActivityAttributes" and s["alert"]["title"] == "Hyperday"


def test_real_send_headers_and_jwt(tmp_path):
    import httpx
    import jwt as pyjwt
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from hyperday_push.apns import APNs

    key = ec.generate_private_key(ec.SECP256R1())
    p8 = tmp_path / "AuthKey_TEST.p8"
    p8.write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                     serialization.NoEncryption()))
    cfg = Config(auth_token=TOKEN, team_id="TEAM123456", key_id="KEY1234567", key_path=str(p8))
    assert not cfg.dry_run
    seen = {}

    def handler(req: httpx.Request):
        seen["url"], seen["headers"], seen["body"] = str(req.url), req.headers, json.loads(req.content)
        return httpx.Response(200)

    apns = APNs(cfg, client=httpx.AsyncClient(transport=httpx.MockTransport(handler)))
    code, _ = asyncio.run(apns.send("devtoken", build_payload("update", {"content_state": CS}, 1)))
    assert code == 200
    assert seen["url"] == "https://api.sandbox.push.apple.com/3/device/devtoken"
    assert seen["headers"]["apns-topic"] == "com.prabhu.daylive.push-type.liveactivity"
    assert seen["headers"]["apns-push-type"] == "liveactivity"
    tok = seen["headers"]["authorization"].split()[1]
    claims = pyjwt.decode(tok, key.public_key(), algorithms=["ES256"])
    assert claims["iss"] == "TEAM123456" and pyjwt.get_unverified_header(tok)["kid"] == "KEY1234567"
