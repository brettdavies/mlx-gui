import asyncio
from pathlib import Path
import pytest
import httpx

from fastapi import FastAPI
from httpx import ASGITransport

from mlx_gui.server import create_app
from mlx_gui.database import DatabaseManager
import mlx_gui.database as db_mod
import mlx_gui.model_manager as mm_mod
from mlx_gui.models import Model, ModelStatus

from tests.unit._stubs import StubModelManager


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def tmp_db_dir(tmp_path) -> Path:
    return tmp_path


@pytest.fixture
def test_db(tmp_db_dir: Path):
    db_path = tmp_db_dir / "test.db"
    manager = DatabaseManager(str(db_path))
    db_mod.db_manager = manager
    yield manager
    manager.close()
    db_mod.db_manager = None


@pytest.fixture
def stub_model_manager(monkeypatch):
    stub = StubModelManager()
    monkeypatch.setattr(mm_mod, "get_model_manager", lambda: stub)
    return stub


@pytest.fixture
def app(test_db, stub_model_manager) -> FastAPI:
    return create_app()


@pytest.fixture
async def client(app: FastAPI):
    async with httpx.AsyncClient(transport=ASGITransport(app=app, lifespan="on"), base_url="http://test") as c:
        yield c


@pytest.fixture
def seed_models(test_db: DatabaseManager):
    with test_db.get_session() as s:
        def add(name: str, model_type: str):
            m = Model(
                name=name,
                path=f"stub/{name}",
                model_type=model_type,
                memory_required_gb=0.1,
                status=ModelStatus.UNLOADED.value,
            )
            s.add(m)
            s.commit()
        add("stub-text", "text")
        add("stub-embedding", "embedding")
        add("stub-audio", "audio")
        add("stub-vision", "vision")