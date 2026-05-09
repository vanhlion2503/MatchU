from __future__ import annotations

import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import numpy as np
from firebase_admin import firestore

from app.core.config import get_settings
from app.services.face_template_crypto import (
    FaceTemplateCryptoError,
    decrypt_embedding,
    encrypt_embedding,
)
from app.services.firebase_identity import ensure_firebase_app
from app.services.similarity import cosine_similarity


@dataclass(frozen=True)
class EnrollmentResult:
    enrolled: bool
    model_version: str


@dataclass(frozen=True)
class ReauthResult:
    success: bool
    reason: str | None = None
    similarity: float | None = None
    threshold: float | None = None
    session_id: str | None = None
    expires_at: datetime | None = None


def _db() -> firestore.Client:
    ensure_firebase_app()
    return firestore.client()


def _normalize_embedding(embedding: np.ndarray) -> np.ndarray:
    vector = np.asarray(embedding, dtype=np.float32).reshape(-1)
    norm = float(np.linalg.norm(vector))
    if norm <= 1e-12:
        raise ValueError("Face embedding has zero norm.")
    return vector / norm


def build_enrollment_template(*embeddings: np.ndarray) -> np.ndarray:
    normalized = [_normalize_embedding(embedding) for embedding in embeddings]
    if not normalized:
        raise ValueError("At least one embedding is required.")
    template = np.mean(np.stack(normalized, axis=0), axis=0)
    return _normalize_embedding(template)


def store_face_enrollment(
    *,
    uid: str,
    selfie_embedding: np.ndarray,
    live_embedding: np.ndarray,
    pair_similarity: float,
    pair_threshold: float,
) -> EnrollmentResult:
    settings = get_settings()
    template = build_enrollment_template(selfie_embedding, live_embedding)
    encrypted_template = encrypt_embedding(
        uid=uid,
        embedding=template,
        model_version=settings.face_model_version,
    )

    db = _db()
    enrollment_ref = db.collection("faceEnrollments").document(uid)
    user_ref = db.collection("users").document(uid)
    existing = enrollment_ref.get()

    enrollment_payload = {
        "uid": uid,
        "template": encrypted_template,
        "templateFormat": "insightface-normalized-mean-float32",
        "modelVersion": settings.face_model_version,
        "embeddingSize": int(template.size),
        "pairSimilarity": float(pair_similarity),
        "pairThreshold": float(pair_threshold),
        "isActive": True,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        "lastVerifiedAt": firestore.SERVER_TIMESTAMP,
    }
    if not existing.exists:
        enrollment_payload["createdAt"] = firestore.SERVER_TIMESTAMP

    batch = db.batch()
    batch.set(enrollment_ref, enrollment_payload, merge=True)
    batch.set(
        user_ref,
        {
            "isFaceVerified": True,
            "faceVerifiedAt": firestore.SERVER_TIMESTAMP,
            "faceVerificationVersion": settings.face_model_version,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    batch.commit()

    return EnrollmentResult(enrolled=True, model_version=settings.face_model_version)


def reauthenticate_face(
    *,
    uid: str,
    live_embedding: np.ndarray,
) -> ReauthResult:
    settings = get_settings()
    db = _db()
    enrollment_ref = db.collection("faceEnrollments").document(uid)
    enrollment_doc = enrollment_ref.get()
    if not enrollment_doc.exists:
        return ReauthResult(success=False, reason="face_not_enrolled")

    data = enrollment_doc.to_dict() or {}
    if data.get("isActive") is False:
        return ReauthResult(success=False, reason="face_enrollment_inactive")

    model_version = str(data.get("modelVersion") or "")
    if model_version != settings.face_model_version:
        return ReauthResult(success=False, reason="face_model_version_mismatch")

    encrypted_template = data.get("template")
    if not isinstance(encrypted_template, dict):
        return ReauthResult(success=False, reason="face_template_missing")

    template = decrypt_embedding(
        uid=uid,
        encrypted_template=encrypted_template,
        model_version=model_version,
    )
    live_template = _normalize_embedding(live_embedding)
    score = cosine_similarity(template, live_template)
    threshold = settings.reauth_similarity_threshold
    if score < threshold:
        return ReauthResult(
            success=False,
            reason="face_mismatch",
            similarity=score,
            threshold=threshold,
        )

    expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=settings.reauth_session_ttl_minutes
    )
    session_id = secrets.token_urlsafe(24)
    session_ref = db.collection("faceReauthSessions").document(session_id)

    batch = db.batch()
    batch.set(
        session_ref,
        {
            "uid": uid,
            "status": "valid",
            "purpose": "face_reauth",
            "similarity": float(score),
            "threshold": float(threshold),
            "createdAt": firestore.SERVER_TIMESTAMP,
            "expiresAt": expires_at,
        },
    )
    batch.set(
        enrollment_ref,
        {
            "lastVerifiedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    batch.commit()

    return ReauthResult(
        success=True,
        similarity=score,
        threshold=threshold,
        session_id=session_id,
        expires_at=expires_at,
    )


__all__ = [
    "FaceTemplateCryptoError",
    "EnrollmentResult",
    "ReauthResult",
    "store_face_enrollment",
    "reauthenticate_face",
]
