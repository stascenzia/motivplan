from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import sync as sync_service
from app.auth import require_token
from app.db import get_session
from app.models import Task, WorkSession
from app.schemas import DayOut, SessionOut, SyncRequest, SyncResponse, TaskOut

DbSession = Annotated[Session, Depends(get_session)]

router = APIRouter(dependencies=[Depends(require_token)])


@router.post("/sync")
def sync(request: SyncRequest, db: DbSession) -> SyncResponse:
    return sync_service.sync(db, request)


# Routes de débogage, en lecture seule.


@router.get("/tasks")
def list_tasks(db: DbSession, include_deleted: bool = False) -> list[TaskOut]:
    query = select(Task).order_by(Task.created_at)
    if not include_deleted:
        query = query.where(Task.deleted_at.is_(None))
    return [TaskOut.model_validate(row) for row in db.scalars(query)]


@router.get("/sessions")
def list_sessions(db: DbSession, include_deleted: bool = False) -> list[SessionOut]:
    query = select(WorkSession).order_by(WorkSession.scheduled_date, WorkSession.order_index)
    if not include_deleted:
        query = query.where(WorkSession.deleted_at.is_(None))
    return [SessionOut.model_validate(row) for row in db.scalars(query)]


@router.get("/days/{day}")
def get_day(day: date, db: DbSession) -> DayOut:
    tasks = db.scalars(
        select(Task)
        .where(Task.scheduled_date == day, Task.deleted_at.is_(None))
        .order_by(Task.order_index)
    )
    sessions = db.scalars(
        select(WorkSession)
        .where(WorkSession.scheduled_date == day, WorkSession.deleted_at.is_(None))
        .order_by(WorkSession.order_index)
    )
    return DayOut(
        date=day,
        tasks=[TaskOut.model_validate(row) for row in tasks],
        sessions=[SessionOut.model_validate(row) for row in sessions],
    )


@router.get("/progress")
def progress() -> list[dict[str, object]]:
    # Points et progression : v2.
    return []
