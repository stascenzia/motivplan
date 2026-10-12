import hmac
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings

bearer = HTTPBearer(auto_error=False)


def require_token(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> None:
    """Jeton statique, comparé en temps constant. Sans jeton configuré, tout est refusé."""
    expected = settings.api_token
    if not expected:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "API token not configured")
    provided = credentials.credentials if credentials else ""
    if not hmac.compare_digest(provided.encode(), expected.encode()):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Invalid token", headers={"WWW-Authenticate": "Bearer"}
        )
