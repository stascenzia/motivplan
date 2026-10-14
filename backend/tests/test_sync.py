from typing import Any

from fastapi.testclient import TestClient

from tests.conftest import AUTH, later, section, session_record, task


def sync(client: TestClient, **body: Any) -> dict[str, Any]:
    response = client.post("/sync", json=body, headers=AUTH)
    assert response.status_code == 200, response.text
    return response.json()


def ids(records: list[dict[str, Any]]) -> list[str]:
    return [record["id"] for record in records]


def test_first_sync_on_empty_server_returns_nothing(client: TestClient) -> None:
    body = sync(client)
    assert body["tasks"] == []
    assert body["sessions"] == []
    assert body["server_time"]


def test_upsert_creates_task_without_echoing_it_back(client: TestClient) -> None:
    created = task(title="Réserver le train")
    body = sync(client, tasks=[created])
    assert body["tasks"] == []

    stored = client.get("/tasks", headers=AUTH).json()
    assert ids(stored) == [created["id"]]
    assert stored[0]["title"] == "Réserver le train"
    assert stored[0]["server_updated_at"]


def test_other_device_receives_changes_since_cursor(client: TestClient) -> None:
    phone = sync(client, tasks=[task(title="A")])
    ipad_first = sync(client)
    assert [t["title"] for t in ipad_first["tasks"]] == ["A"]

    sync(client, since=phone["server_time"], tasks=[task(title="B")])
    ipad_next = sync(client, since=ipad_first["server_time"])
    assert [t["title"] for t in ipad_next["tasks"]] == ["B"]

    # Rien de neuf depuis le dernier curseur.
    assert sync(client, since=ipad_next["server_time"])["tasks"] == []


def test_lww_newer_client_write_wins(client: TestClient) -> None:
    original = task(title="Version 1")
    sync(client, tasks=[original])

    edited = {**original, "title": "Version 2", "updated_at": later(5)}
    body = sync(client, tasks=[edited])
    assert body["tasks"] == []
    assert client.get("/tasks", headers=AUTH).json()[0]["title"] == "Version 2"


def test_lww_older_client_write_loses_and_gets_server_version(client: TestClient) -> None:
    original = task(title="Version récente", updated_at=later(10))
    first = sync(client, tasks=[original])

    stale = {**original, "title": "Version ancienne", "updated_at": later(1)}
    body = sync(client, since=first["server_time"], tasks=[stale])
    assert [t["title"] for t in body["tasks"]] == ["Version récente"]
    assert client.get("/tasks", headers=AUTH).json()[0]["title"] == "Version récente"


def test_resending_same_payload_is_idempotent(client: TestClient) -> None:
    record = task(title="Même envoi")
    first = sync(client, tasks=[record])
    stored_before = client.get("/tasks", headers=AUTH).json()[0]

    second = sync(client, since=first["server_time"], tasks=[record])
    stored_after = client.get("/tasks", headers=AUTH).json()[0]

    assert stored_after == stored_before
    assert [t["title"] for t in second["tasks"]] == ["Même envoi"]


def test_duplicate_ids_in_one_request_keep_newest(client: TestClient) -> None:
    record = task(title="v1")
    newer = {**record, "title": "v2", "updated_at": later(1)}
    sync(client, tasks=[record, newer])
    stored = client.get("/tasks", headers=AUTH).json()
    assert [t["title"] for t in stored] == ["v2"]


def test_tombstone_is_hidden_but_synced(client: TestClient) -> None:
    record = task()
    cursor = sync(client, tasks=[record])["server_time"]
    observer = sync(client)["server_time"]

    deleted = {**record, "updated_at": later(3), "deleted_at": later(3)}
    sync(client, since=cursor, tasks=[deleted])

    assert client.get("/tasks", headers=AUTH).json() == []
    with_deleted = client.get("/tasks", params={"include_deleted": True}, headers=AUTH).json()
    assert with_deleted[0]["deleted_at"] is not None

    propagated = sync(client, since=observer)["tasks"]
    assert ids(propagated) == [record["id"]]
    assert propagated[0]["deleted_at"] is not None


def test_sessions_sync(client: TestClient) -> None:
    parent = task(status="scheduled", scheduled_date="2026-10-12", order_index=1024)
    work = session_record(parent["id"])
    sync(client, tasks=[parent], sessions=[work])

    other_device = sync(client)
    assert ids(other_device["sessions"]) == [work["id"]]
    assert other_device["sessions"][0]["task_id"] == parent["id"]


def test_anchored_task_requires_time(client: TestClient) -> None:
    invalid = task(status="scheduled", scheduled_date="2026-10-12", is_anchored=True)
    response = client.post("/sync", json={"tasks": [invalid]}, headers=AUTH)
    assert response.status_code == 422


def test_naive_timestamps_are_refused(client: TestClient) -> None:
    invalid = task(updated_at="2026-10-12T08:00:00")
    response = client.post("/sync", json={"tasks": [invalid]}, headers=AUTH)
    assert response.status_code == 422


def test_unknown_enum_value_is_refused(client: TestClient) -> None:
    response = client.post("/sync", json={"tasks": [task(tag="prioritaire")]}, headers=AUTH)
    assert response.status_code == 422


def test_timestamps_round_trip_in_utc(client: TestClient) -> None:
    record = task(updated_at="2026-10-12T10:00:00+02:00", created_at="2026-10-12T10:00:00+02:00")
    sync(client, tasks=[record])
    stored = client.get("/tasks", headers=AUTH).json()[0]
    assert stored["updated_at"].startswith("2026-10-12T08:00:00")


def test_sections_sync_with_last_write_wins(client: TestClient) -> None:
    films = section()
    sync(client, sections=[films])
    assert ids(client.get("/sections", headers=AUTH).json()) == [films["id"]]

    renamed = section(id=films["id"], name="Cinema", updated_at=later(5))
    stale = section(id=films["id"], name="Ancien nom", updated_at=later(1))
    body = sync(client, sections=[renamed])
    assert body["sections"] == []
    body = sync(client, sections=[stale])
    assert [record["name"] for record in body["sections"]] == ["Cinema"]


def test_task_carries_section_tag_and_review(client: TestClient) -> None:
    films = section()
    film = task(
        title="Past Lives",
        section_id=films["id"],
        tag="detente",
        status="done",
        completed_at=later(10),
        review="aime",
        review_note="Tres beau",
    )
    sync(client, sections=[films], tasks=[film])
    stored = client.get("/tasks", headers=AUTH).json()[0]
    assert stored["section_id"] == films["id"]
    assert stored["review"] == "aime"
    assert stored["review_note"] == "Tres beau"


def test_unknown_repeat_rule_is_refused(client: TestClient) -> None:
    response = client.post("/sync", json={"sections": [section(repeat="weekly")]}, headers=AUTH)
    assert response.status_code == 422
