import uuid
from datetime import date, time
from typing import Literal, Self

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator

Tag = Literal["urgent", "travail", "medium", "detente"]
Review = Literal["aime", "bof", "pas_aime"]
Repeat = Literal["none", "daily", "permanent"]
Kind = Literal["tasks", "memory", "checklist", "periods"]
Space = Literal["tasks", "memory"]
Template = Literal["courses", "film", "recette", "voyage", "liste", "valise"]
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
    section_id: uuid.UUID | None = None
    tag: Tag | None = None
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
    review: Review | None = None
    review_note: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    space: Space | None = None
    # JSON produit par le client, stocké tel quel (ADR-016).
    subtasks: str | None = None
    fields: str | None = None

    @model_validator(mode="after")
    def anchor_needs_time(self) -> Self:
        if self.is_anchored and self.anchor_time is None:
            raise ValueError("anchor_time is required when is_anchored is true")
        return self

    @model_validator(mode="after")
    def period_in_order(self) -> Self:
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date must not be before start_date")
        return self


class TaskOut(TaskIn):
    server_updated_at: AwareDatetime


class SectionIn(SyncedRecord):
    name: str = Field(min_length=1)
    symbol: str = Field(min_length=1, max_length=64)
    sort_index: int
    default_duration: int | None = Field(default=None, ge=5)
    is_plannable: bool = True
    keeps_memory: bool = False
    repeat: Repeat = "none"
    kind: Kind | None = None
    template: Template | None = None


class SectionOut(SectionIn):
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
    sections: list[SectionIn] = []
    sessions: list[SessionIn] = []


class SyncResponse(BaseModel):
    server_time: AwareDatetime
    tasks: list[TaskOut]
    sections: list[SectionOut]
    sessions: list[SessionOut]


class DayOut(BaseModel):
    date: date
    tasks: list[TaskOut]
    sessions: list[SessionOut]
