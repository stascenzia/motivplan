import uuid
from datetime import date, time
from typing import Literal, Self

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator

Category = Literal["quotidienne", "courte", "moyenne", "longue", "pro"]
Importance = Literal["basse", "normale", "haute"]
Status = Literal["inbox", "scheduled", "done", "archived"]
Source = Literal["manual", "siri", "widget"]


class SyncedRecord(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    created_at: AwareDatetime
    updated_at: AwareDatetime
    deleted_at: AwareDatetime | None = None


class TaskIn(SyncedRecord):
    title: str = Field(min_length=1)
    notes: str | None = None
    category: Category | None = None
    importance: Importance | None = None
    due_date: date | None = None
    duration_min: int | None = Field(default=None, ge=5)
    status: Status
    scheduled_date: date | None = None
    order_index: int | None = None
    is_anchored: bool = False
    anchor_time: time | None = None
    completed_at: AwareDatetime | None = None
    postpone_count: int = Field(default=0, ge=0)
    source: Source

    @model_validator(mode="after")
    def anchor_needs_time(self) -> Self:
        if self.is_anchored and self.anchor_time is None:
            raise ValueError("anchor_time is required when is_anchored is true")
        return self


class TaskOut(TaskIn):
    server_updated_at: AwareDatetime


class SessionIn(SyncedRecord):
    task_id: uuid.UUID
    scheduled_date: date
    order_index: int
    duration_min: int = Field(ge=5)
    completed_at: AwareDatetime | None = None


class SessionOut(SessionIn):
    server_updated_at: AwareDatetime


class SyncRequest(BaseModel):
    # Valeur `server_time` de la réponse précédente ; absente au premier appel.
    since: AwareDatetime | None = None
    tasks: list[TaskIn] = []
    sessions: list[SessionIn] = []


class SyncResponse(BaseModel):
    server_time: AwareDatetime
    tasks: list[TaskOut]
    sessions: list[SessionOut]


class DayOut(BaseModel):
    date: date
    tasks: list[TaskOut]
    sessions: list[SessionOut]
