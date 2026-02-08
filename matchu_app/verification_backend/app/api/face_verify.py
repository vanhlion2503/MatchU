from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from app.core.config import get_settings
from app.services.face_embedding import extract_embedding, get_face_engine_error
from app.services.similarity import cosine_similarity

router = APIRouter(tags=["Face Verification"])


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


@router.post("/face/verify")
async def verify_face(
    selfie: UploadFile = File(...),
    live: UploadFile | None = File(None),
    live_frame: UploadFile | None = File(None),
) -> dict:
    settings = get_settings()
    live_file = _pick_live_file(live=live, live_frame=live_frame)

    _validate_content_type(selfie, "selfie")
    _validate_content_type(live_file, "live_frame")

    try:
        selfie_bytes = await _read_bytes(selfie, "selfie")
        live_bytes = await _read_bytes(live_file, "live_frame")

        emb_selfie, selfie_error = extract_embedding(selfie_bytes)
        emb_live, live_error = extract_embedding(live_bytes)

        if selfie_error == "engine_unavailable" or live_error == "engine_unavailable":
            detail = "Face recognition engine is unavailable."
            engine_error = get_face_engine_error()
            if engine_error:
                detail = f"{detail} {engine_error}"
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=detail,
            )

        if selfie_error == "invalid_image" or live_error == "invalid_image":
            return {
                "success": False,
                "reason": "invalid_image",
            }

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

        return {
            "success": True,
            "similarity": score,
            "threshold": settings.similarity_threshold,
        }
    finally:
        await selfie.close()
        if live is not None:
            await live.close()
        if live_frame is not None and live_frame is not live:
            await live_frame.close()
