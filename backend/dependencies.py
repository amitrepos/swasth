"""Shared FastAPI dependencies."""
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Annotated
import models
import auth
from database import get_db


def get_current_user(
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db),
) -> models.User:
    """Extract and validate the current user from the JWT token.

    Use as a dependency in any route that requires authentication:
        user: models.User = Depends(get_current_user)
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    return user
