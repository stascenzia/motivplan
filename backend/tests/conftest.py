import os
import uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import Settings, get_settings
from app.db import Base, get_session
from app.main import app

TOKEN = "test-token"
AUTH = {"Authorization": f"Bearer {TOKEN}"}

# MOTIVPLAN_TEST_DATABASE_URL permet de rejouer la suite sur Postgres ; SQLite en mémoire par défaut.
TEST_DATABASE_URL = os.environ.get("MOTIVPLAN_TEST_DATABASE_URL", "sqlite://")


@pytest.fixture
def db_session_factory() -> Iterator[sessionmaker[Session]]:
    if TEST_DATABASE_URL.startswith("sqlite"):
        engine = create_engine(
            TEST_DATABASE_URL, connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
    else:
        engine = create_engine(TEST_DATABASE_URL)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, expire_on_commit=False)
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def client(db_session_factory: sessionmaker[Session]) -> Iterator[TestClient]:
    def session_override() -> Iterator[Session]:
        with db_session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = session_override
    app.dependency_overrides[get_settings] = lambda: Settings(api_token=TOKEN)
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


T0 = datetime(2026, 10, 12, 8, 0, tzinfo=UTC)


def iso(moment: datetime) -> str:
    return moment.isoformat()


def task(**overrides: Any) -> dict[str, Any]:
    """Tâche valide au format JSON de l'API, modifiable champ par champ."""
    base: dict[str, Any] = {
        "id": str(uuid.uuid4()),
        "title": "Appeler le plombier",
        "status": "inbox",
        "source": "manual",
        "created_at": iso(T0),
        "updated_at": iso(T0),
    }
    base.update(overrides)
    return base


def section(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "id": str(uuid.uuid4()),
        "name": "Films et séries",
        "symbol": "film",
        "sort_index": 1024,
        "is_plannable": False,
        "keeps_memory": True,
        "repeat": "none",
        "created_at": iso(T0),
        "updated_at": iso(T0),
    }
    base.update(overrides)
    return base


def session_record(task_id: str, **overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "id": str(uuid.uuid4()),
        "task_id": task_id,
        "scheduled_date": "2026-10-12",
        "order_index": 1024,
        "duration_min": 60,
        "created_at": iso(T0),
        "updated_at": iso(T0),
    }
    base.update(overrides)
    return base


def later(minutes: int) -> str:
    return iso(T0 + timedelta(minutes=minutes))
