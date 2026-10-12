from collections.abc import Iterator
from datetime import UTC, datetime
from functools import lru_cache

from sqlalchemy import DateTime, Engine, create_engine
from sqlalchemy.engine import Dialect
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.types import TypeDecorator

from app.config import get_settings


class UTCDateTime(TypeDecorator[datetime]):
    """Horodatage toujours en UTC et toujours « aware », y compris sous SQLite."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("naive datetime refused: timestamps must carry a timezone")
        value = value.astimezone(UTC)
        return value.replace(tzinfo=None) if dialect.name == "sqlite" else value

    def process_result_value(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


class Base(DeclarativeBase):
    pass


@lru_cache
def get_engine() -> Engine:
    return create_engine(get_settings().database_url, pool_pre_ping=True)


def get_session() -> Iterator[Session]:
    session = sessionmaker(bind=get_engine(), expire_on_commit=False)()
    try:
        yield session
    finally:
        session.close()
