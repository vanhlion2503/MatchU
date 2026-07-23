from __future__ import annotations

from datetime import datetime, timezone

from firebase_admin import firestore
from google.cloud.firestore_v1.transaction import transactional

from app.services.firebase_identity import ensure_firebase_app


class TemplateUpdateAuthorizationError(ValueError):
    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


def _db() -> firestore.Client:
    ensure_firebase_app()
    return firestore.client()


def face_enrollment_exists(uid: str) -> bool:
    snapshot = _db().collection("faceEnrollments").document(uid).get()
    return snapshot.exists


def validate_template_update_authorization_payload(
    *,
    data: dict | None,
    uid: str,
    device_id: str,
    now: datetime,
) -> None:
    payload = data or {}
    expires_at = payload.get("expiresAt")
    if (
        payload.get("uid") != uid
        or payload.get("deviceId") != device_id
        or payload.get("purpose") != "face_template_update"
        or payload.get("method") != "chat_pin"
        or payload.get("status") != "valid"
        or not isinstance(expires_at, datetime)
        or expires_at <= now
    ):
        raise TemplateUpdateAuthorizationError(
            "template_update_authorization_invalid"
        )


def consume_template_update_authorization(
    *,
    authorization_id: str,
    uid: str,
    device_id: str,
) -> None:
    clean_authorization_id = (authorization_id or "").strip()
    clean_device_id = (device_id or "").strip()
    if not clean_authorization_id:
        raise TemplateUpdateAuthorizationError(
            "template_update_authorization_required"
        )

    db = _db()
    ref = db.collection("faceTemplateUpdateAuthorizations").document(
        clean_authorization_id
    )
    transaction = db.transaction()

    @transactional
    def consume(tx: firestore.Transaction) -> None:
        snapshot = ref.get(transaction=tx)
        validate_template_update_authorization_payload(
            data=snapshot.to_dict() if snapshot.exists else None,
            uid=uid,
            device_id=clean_device_id,
            now=datetime.now(timezone.utc),
        )
        tx.update(
            ref,
            {
                "status": "consumed",
                "consumedAt": firestore.SERVER_TIMESTAMP,
            },
        )

    consume(transaction)


__all__ = [
    "TemplateUpdateAuthorizationError",
    "consume_template_update_authorization",
    "face_enrollment_exists",
    "validate_template_update_authorization_payload",
]
