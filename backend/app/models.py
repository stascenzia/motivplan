import uuid
from datetime import date, datetime, time

from sqlalchemy import Boolean, Date, Integer, String, Text, Time, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base, UTCDateTime


class SyncedMixin:
    """Colonnes communes aux tables synchronisées (ADR-009).

    `updated_at` vient de l'horloge client et sert au « dernière écriture gagnante ».
    `server_updated_at` vient de l'horloge serveur et sert de curseur : on ne filtre jamais
    sur l'horloge client, à cause des dérives.
    """

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime)
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime)
    deleted_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    server_updated_at: Mapped[datetime] = mapped_column(UTCDateTime, index=True)


class Task(SyncedMixin, Base):
    __tablename__ = "tasks"

    title: Mapped[str] = mapped_column(Text)
    notes: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str | None] = mapped_column(String(16))
    importance: Mapped[str | None] = mapped_column(String(16))
    due_date: Mapped[date | None] = mapped_column(Date)
    duration_min: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(16))
    scheduled_date: Mapped[date | None] = mapped_column(Date, index=True)
    order_index: Mapped[int | None] = mapped_column(Integer)
    is_anchored: Mapped[bool] = mapped_column(Boolean, default=False)
    anchor_time: Mapped[time | None] = mapped_column(Time)
    completed_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    postpone_count: Mapped[int] = mapped_column(Integer, default=0)
    source: Mapped[str] = mapped_column(String(16))


class WorkSession(SyncedMixin, Base):
    """`Session` du cahier (§2.1). Pas de clé étrangère : une session peut arriver avant sa tâche."""

    __tablename__ = "sessions"

    task_id: Mapped[uuid.UUID] = mapped_column(Uuid, index=True)
    scheduled_date: Mapped[date] = mapped_column(Date, index=True)
    order_index: Mapped[int] = mapped_column(Integer)
    duration_min: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
