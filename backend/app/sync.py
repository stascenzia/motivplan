"""Synchronisation par drapeau, dernière écriture gagnante, curseur serveur (ADR-009)."""

import uuid
from datetime import UTC, datetime

from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import SyncedMixin, Task, WorkSession
from app.schemas import SessionOut, SyncRequest, SyncResponse, TaskOut


def sync(db: Session, request: SyncRequest) -> SyncResponse:
    now = datetime.now(UTC)

    tasks_accepted, tasks_rejected = _upsert(db, Task, request.tasks, now)
    sessions_accepted, sessions_rejected = _upsert(db, WorkSession, request.sessions, now)
    db.flush()

    tasks = _changes(db, Task, request.since, tasks_accepted, tasks_rejected)
    sessions = _changes(db, WorkSession, request.since, sessions_accepted, sessions_rejected)
    db.commit()

    return SyncResponse(
        server_time=now,
        tasks=[TaskOut.model_validate(row) for row in tasks],
        sessions=[SessionOut.model_validate(row) for row in sessions],
    )


def _upsert[M: SyncedMixin](
    db: Session, model: type[M], incoming: list[BaseModel], now: datetime
) -> tuple[set[uuid.UUID], set[uuid.UUID]]:
    """Applique chaque enregistrement reçu s'il est plus récent (horloge client) que le stocké.

    À égalité, le serveur garde sa version : renvoyer deux fois le même envoi ne change rien.
    """
    accepted: set[uuid.UUID] = set()
    rejected: set[uuid.UUID] = set()
    if not incoming:
        return accepted, rejected

    ids = [record.id for record in incoming]  # type: ignore[attr-defined]
    existing = {row.id: row for row in db.scalars(select(model).where(model.id.in_(ids)))}

    for record in incoming:
        data = record.model_dump()
        row = existing.get(data["id"])
        if row is None:
            row = model(**data, server_updated_at=now)
            db.add(row)
            existing[row.id] = row
            accepted.add(row.id)
            rejected.discard(row.id)
        elif data["updated_at"] > row.updated_at:
            for key, value in data.items():
                setattr(row, key, value)
            row.server_updated_at = now
            accepted.add(row.id)
            rejected.discard(row.id)
        elif row.id not in accepted:
            rejected.add(row.id)
    return accepted, rejected


def _changes[M: SyncedMixin](
    db: Session,
    model: type[M],
    since: datetime | None,
    accepted: set[uuid.UUID],
    rejected: set[uuid.UUID],
) -> list[M]:
    """Ce que le client doit appliquer : tout ce qui a changé côté serveur depuis `since`,
    sauf ce qu'il vient lui-même d'écrire, plus la version serveur de ce qui a été refusé."""
    query = select(model)
    if since is not None:
        query = query.where(model.server_updated_at > since)
    rows = [row for row in db.scalars(query) if row.id not in accepted]

    missing = rejected - {row.id for row in rows}
    if missing:
        rows += db.scalars(select(model).where(model.id.in_(missing)))
    return sorted(rows, key=lambda row: (row.server_updated_at, str(row.id)))
