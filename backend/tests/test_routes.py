from fastapi.testclient import TestClient

from app.config import Settings, get_settings
from app.main import app
from tests.conftest import AUTH, session_record, task


def test_health_needs_no_token(client: TestClient) -> None:
    assert client.get("/health").status_code == 200


def test_missing_token_is_rejected(client: TestClient) -> None:
    assert client.get("/tasks").status_code == 401
    assert client.post("/sync", json={}).status_code == 401


def test_wrong_token_is_rejected(client: TestClient) -> None:
    response = client.get("/tasks", headers={"Authorization": "Bearer nope"})
    assert response.status_code == 401


def test_unconfigured_token_refuses_everything(client: TestClient) -> None:
    app.dependency_overrides[get_settings] = lambda: Settings(api_token="")
    assert client.get("/tasks", headers=AUTH).status_code == 503


def test_day_lists_scheduled_tasks_in_order(client: TestClient) -> None:
    second = task(title="Deux", status="scheduled", scheduled_date="2026-10-12", order_index=2048)
    first = task(title="Un", status="scheduled", scheduled_date="2026-10-12", order_index=1024)
    other_day = task(title="Demain", status="scheduled", scheduled_date="2026-10-13", order_index=1024)
    inbox = task(title="Boîte")
    work = session_record(first["id"])
    client.post(
        "/sync",
        json={"tasks": [second, first, other_day, inbox], "sessions": [work]},
        headers=AUTH,
    )

    day = client.get("/days/2026-10-12", headers=AUTH).json()
    assert day["date"] == "2026-10-12"
    assert [t["title"] for t in day["tasks"]] == ["Un", "Deux"]
    assert [s["id"] for s in day["sessions"]] == [work["id"]]


def test_sessions_route_lists_live_sessions(client: TestClient) -> None:
    parent = task()
    live = session_record(parent["id"])
    gone = session_record(parent["id"], deleted_at="2026-10-12T09:00:00+00:00")
    client.post("/sync", json={"tasks": [parent], "sessions": [live, gone]}, headers=AUTH)
    assert [s["id"] for s in client.get("/sessions", headers=AUTH).json()] == [live["id"]]


def test_progress_is_empty_in_v1(client: TestClient) -> None:
    assert client.get("/progress", headers=AUTH).json() == []
