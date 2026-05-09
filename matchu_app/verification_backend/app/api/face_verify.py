from __future__ import annotations

from dataclasses import dataclass
from datetime import timezone

import numpy as np
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.core.config import get_settings
from app.services.face_enrollment import (
    FaceTemplateCryptoError,
    reauthenticate_face,
    store_face_enrollment,
)
from app.services.face_embedding import extract_embedding, get_face_engine_error
from app.services.firebase_identity import FirebaseUser, require_firebase_user
from app.services.similarity import cosine_similarity

router = APIRouter(tags=["Face Verification"])


@dataclass(frozen=True)
class VerifiedPair:
    selfie_embedding: np.ndarray
    live_embedding: np.ndarray
    similarity: float
    threshold: float


def _pick_live_file(live: UploadFile | None, live_frame: UploadFile | None) -> UploadFile:
    # Keep compatibility with both field names:
    # - `live` (old backend)
    # - `live_frame` (Flutter service draft)
    selected = live_frame or live
    if selected is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Missing file field: provide `live` or `live_frame`.",
        )
    return selected


def _validate_content_type(upload: UploadFile, field_name: str) -> None:
    content_type = (upload.content_type or "").lower()
    if (
        content_type
        and not content_type.startswith("image/")
        and content_type != "application/octet-stream"
    ):
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"{field_name} must be an image upload.",
        )


async def _read_bytes(upload: UploadFile, field_name: str) -> bytes:
    settings = get_settings()
    max_bytes = settings.max_upload_size_mb * 1024 * 1024
    data = await upload.read(max_bytes + 1)

    if not data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} is empty.",
        )

    if len(data) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"{field_name} exceeds {settings.max_upload_size_mb} MB.",
        )

    return data


def _raise_engine_unavailable() -> None:
    detail = "Face recognition engine is unavailable."
    engine_error = get_face_engine_error()
    if engine_error:
        detail = f"{detail} {engine_error}"
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=detail,
    )


def _embedding_error_response(error: str | None) -> dict | None:
    if error == "engine_unavailable":
        _raise_engine_unavailable()
    if error == "invalid_image":
        return {"success": False, "reason": "invalid_image"}
    if error == "face_not_detected":
        return {"success": False, "reason": "face_not_detected"}
    return None


async def _verify_uploaded_pair(
    *,
    selfie: UploadFile,
    live_file: UploadFile,
) -> VerifiedPair | dict:
    settings = get_settings()

    _validate_content_type(selfie, "selfie")
    _validate_content_type(live_file, "live_frame")

    selfie_bytes = await _read_bytes(selfie, "selfie")
    live_bytes = await _read_bytes(live_file, "live_frame")

    emb_selfie, selfie_error = extract_embedding(selfie_bytes)
    selfie_error_response = _embedding_error_response(selfie_error)
    if selfie_error_response is not None:
        return selfie_error_response

    emb_live, live_error = extract_embedding(live_bytes)
    live_error_response = _embedding_error_response(live_error)
    if live_error_response is not None:
        return live_error_response

    if emb_selfie is None or emb_live is None:
        return {
            "success": False,
            "reason": "face_not_detected",
        }

    try:
        score = cosine_similarity(emb_selfie, emb_live)
    except ValueError:
        return {
            "success": False,
            "reason": "embedding_error",
        }

    if score < settings.similarity_threshold:
        return {
            "success": False,
            "reason": "face_mismatch",
            "similarity": score,
            "threshold": settings.similarity_threshold,
        }

    return VerifiedPair(
        selfie_embedding=emb_selfie,
        live_embedding=emb_live,
        similarity=score,
        threshold=settings.similarity_threshold,
    )


@router.post("/face/verify")
async def verify_face(
    selfie: UploadFile = File(...),
    live: UploadFile | None = File(None),
    live_frame: UploadFile | None = File(None),
) -> dict:
    live_file = _pick_live_file(live=live, live_frame=live_frame)

    try:
        result = await _verify_uploaded_pair(selfie=selfie, live_file=live_file)
        if isinstance(result, dict):
            return result

        return {
            "success": True,
            "similarity": result.similarity,
            "threshold": result.threshold,
        }
    finally:
        await selfie.close()
        if live is not None:
            await live.close()
        if live_frame is not None and live_frame is not live:
            await live_frame.close()


@router.post("/face/enroll")
async def enroll_face(
    selfie: UploadFile = File(...),
    live: UploadFile | None = File(None),
    live_frame: UploadFile | None = File(None),
    current_user: FirebaseUser = Depends(require_firebase_user),
) -> dict:
    live_file = _pick_live_file(live=live, live_frame=live_frame)

    try:
        result = await _verify_uploaded_pair(selfie=selfie, live_file=live_file)
        if isinstance(result, dict):
            return result

        try:
            enrollment = store_face_enrollment(
                uid=current_user.uid,
                selfie_embedding=result.selfie_embedding,
                live_embedding=result.live_embedding,
                pair_similarity=result.similarity,
                pair_threshold=result.threshold,
            )
        except FaceTemplateCryptoError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Face template storage is not configured.",
            ) from exc
        except ValueError:
            return {
                "success": False,
                "reason": "embedding_error",
            }

        return {
            "success": enrollment.enrolled,
            "similarity": result.similarity,
            "threshold": result.threshold,
            "modelVersion": enrollment.model_version,
        }
    finally:
        await selfie.close()
        if live is not None:
            await live.close()
        if live_frame is not None and live_frame is not live:
            await live_frame.close()


@router.post("/face/reauth")
async def reauth_face(
    live: UploadFile | None = File(None),
    live_frame: UploadFile | None = File(None),
    current_user: FirebaseUser = Depends(require_firebase_user),
) -> dict:
    live_file = _pick_live_file(live=live, live_frame=live_frame)

    try:
        _validate_content_type(live_file, "live_frame")
        live_bytes = await _read_bytes(live_file, "live_frame")
        live_embedding, live_error = extract_embedding(live_bytes)
        live_error_response = _embedding_error_response(live_error)
        if live_error_response is not None:
            return live_error_response

        if live_embedding is None:
            return {
                "success": False,
                "reason": "face_not_detected",
            }

        try:
            result = reauthenticate_face(
                uid=current_user.uid,
                live_embedding=live_embedding,
            )
        except FaceTemplateCryptoError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Face template storage is not available.",
            ) from exc
        except ValueError:
            return {
                "success": False,
                "reason": "embedding_error",
            }

        response = {
            "success": result.success,
            "reason": result.reason,
            "similarity": result.similarity,
            "threshold": result.threshold,
        }
        if result.success:
            response["sessionId"] = result.session_id
            response["expiresAt"] = result.expires_at.astimezone(
                timezone.utc
            ).isoformat() if result.expires_at else None
        return response
    finally:
        if live is not None:
            await live.close()
        if live_frame is not None and live_frame is not live:
            await live_frame.close()
