import asyncio
import hmac
import logging
import time
from contextlib import asynccontextmanager
from typing import Any, Literal, Optional

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from . import __version__
from .apns import APNs, build_payload
from .config import Config
from .scheduler import loop
from .store import Store

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")


class Event(BaseModel):
    at: float = Field(description="unix seconds to send at")
    kind: Literal["start", "update", "end"]
    content_state: dict[str, Any]
    stale_date: Optional[float] = None
    dismissal_date: Optional[float] = None
    attributes: Optional[dict[str, Any]] = None


class Schedule(BaseModel):
    device_id: str = Field(min_length=4, max_length=64)
    activity_token: Optional[str] = None
    start_token: Optional[str] = None
    events: list[Event] = Field(default_factory=list, max_length=500)


class Tokens(BaseModel):
    device_id: str = Field(min_length=4, max_length=64)
    activity_token: Optional[str] = None
    start_token: Optional[str] = None


class TestPush(BaseModel):
    device_id: str
    content_state: dict[str, Any]


def create_app(cfg: Optional[Config] = None, run_scheduler: bool = True) -> FastAPI:
    cfg = cfg or Config.from_env()
    store = Store(cfg.db_path)
    apns = APNs(cfg)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        task = asyncio.create_task(loop(store, apns, cfg)) if run_scheduler else None
        yield
        if task:
            task.cancel()

    app = FastAPI(title="Hyperday push", version=__version__, lifespan=lifespan)
    app.state.cfg, app.state.store, app.state.apns = cfg, store, apns

    def auth(authorization: str = Header(default="")) -> None:
        expected = f"Bearer {cfg.auth_token}"
        if not hmac.compare_digest(authorization.encode(), expected.encode()):
            raise HTTPException(status_code=401, detail="bad token")

    @app.get("/health")
    def health():
        return {"ok": True, "version": __version__, "dry_run": cfg.dry_run, "apns_env": cfg.apns_env}

    @app.post("/v1/schedule", dependencies=[Depends(auth)])
    def schedule(body: Schedule):
        if body.activity_token is not None or body.start_token is not None:
            store.set_tokens(body.device_id, body.activity_token, body.start_token)
        n = store.replace_schedule(body.device_id, [
            {"at": e.at, "kind": e.kind, "payload": e.model_dump(exclude={"at", "kind"})} for e in body.events
        ])
        return {"ok": True, "scheduled": n, "dry_run": cfg.dry_run}

    @app.post("/v1/tokens", dependencies=[Depends(auth)])
    def tokens(body: Tokens):
        store.set_tokens(body.device_id, body.activity_token, body.start_token)
        return {"ok": True}

    @app.post("/v1/test", dependencies=[Depends(auth)])
    async def test(body: TestPush):
        dev = store.device(body.device_id)
        if not dev or not dev["activity_token"]:
            raise HTTPException(status_code=404, detail="no Live Activity token for this device; tap Go Live first")
        code, reason = await apns.send(dev["activity_token"],
                                       build_payload("update", {"content_state": body.content_state}, time.time()))
        return {"status": code, "reason": reason}

    @app.get("/v1/status", dependencies=[Depends(auth)])
    def status():
        return {
            "dry_run": cfg.dry_run,
            "pending": [{"at": r["fire_at"], "kind": r["kind"], "device": r["device_id"]} for r in store.pending()],
            "recent": [{"at": r["fire_at"], "kind": r["kind"], "status": r["status"]} for r in store.recent()],
        }

    return app


def app() -> FastAPI:  # uvicorn --factory hyperday_push.app:app
    return create_app()
