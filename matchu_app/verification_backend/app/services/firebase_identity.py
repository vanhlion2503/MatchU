from __future__ import annotations

import os
from dataclasses import dataclass

import firebase_admin
from fastapi import Header, HTTPException, status
from firebase_admin import app_check, auth


@dataclass(frozen=True)
class FirebaseUser:
    uid: str
    claims: dict


def ensure_firebase_app() -> None:
    try:
        firebase_admin.get_app()
    except ValueError:
        project_id = os.getenv("FIREBASE_PROJECT_ID", "").strip()
        options = {"projectId": project_id} if project_id else None
        firebase_admin.initialize_app(options=options)


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization bearer token.",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization bearer token.",
        )
    return token.strip()


def _requires_app_check() -> bool:
    return os.getenv("REQUIRE_FIREBASE_APP_CHECK", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


async def require_firebase_user(
    authorization: str | None = Header(default=None),
    x_firebase_appcheck: str | None = Header(default=None),
) -> FirebaseUser:
    ensure_firebase_app()

    if _requires_app_check():
        if not x_firebase_appcheck:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Firebase App Check token.",
            )
        try:
            app_check.verify_token(x_firebase_appcheck)
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase App Check token.",
            ) from exc

    token = _extract_bearer_token(authorization)
    try:
        claims = auth.verify_id_token(token)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase ID token.",
        ) from exc

    uid = str(claims.get("uid") or "").strip()
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase ID token has no uid.",
        )
    return FirebaseUser(uid=uid, claims=claims)
