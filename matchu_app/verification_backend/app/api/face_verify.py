from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import timezone

import numpy as np
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.core.config import get_settings
from app.services.face_enrollment import (
    FaceTemplateCryptoError,
    VIDEO_MATCHING_PURPOSE,
    issue_face_session,
    reauthenticate_face,
    store_face_enrollment,
)
from app.services.face_embedding import (
    FaceObservation,
    extract_embedding,
    extract_face_observation,
    get_face_engine_error,
)
from app.services.firebase_identity import FirebaseUser, require_firebase_user
from app.services.liveness_challenge import (
    LivenessChallengeError,
    consume_liveness_challenge,
    create_liveness_challenge,
    record_liveness_failure,
    reset_liveness_failures,
    validate_pose_evidence,
)
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


async def _verify_liveness_evidence(
    *,
    challenge_id: str,
    challenge_response: str,
    evidence_frames: list[UploadFile],
    current_user: FirebaseUser,
    purpose: str,
    device_id: str,
) -> list[FaceObservation] | dict:
    try:
        decoded = json.loads(challenge_response)
        if not isinstance(decoded, list) or not all(
            isinstance(action, str) for action in decoded
        ):
            raise LivenessChallengeError("challenge_response_invalid")

        actions = consume_liveness_challenge(
            challenge_id=challenge_id,
            uid=current_user.uid,
            device_id=device_id,
            purpose=purpose,
            response_actions=decoded,
        )
        if len(evidence_frames) != len(actions):
            raise LivenessChallengeError("challenge_evidence_incomplete")

        observations: list[FaceObservation] = []
        for index, upload in enumerate(evidence_frames):
            _validate_content_type(upload, f"evidence_frames[{index}]")
            image_bytes = await _read_bytes(upload, f"evidence_frames[{index}]")
            observation, error = extract_face_observation(image_bytes)
            if error == "engine_unavailable":
                _raise_engine_unavailable()
            if observation is None:
                raise LivenessChallengeError(
                    error or "challenge_face_not_detected"
                )
            observations.append(observation)

        validate_pose_evidence(actions, [item.yaw for item in observations])
        return observations
    except (json.JSONDecodeError, LivenessChallengeError) as exc:
        reason = (
            exc.reason
            if isinstance(exc, LivenessChallengeError)
            else "challenge_response_invalid"
        )
        record_liveness_failure(current_user.uid, device_id, reason)
        return {"success": False, "reason": reason}


def _evidence_matches_face(
    observations: list[FaceObservation],
    reference_embedding: np.ndarray,
    threshold: float,
) -> bool:
    return all(
        cosine_similarity(item.embedding, reference_embedding) >= threshold
        for item in observations
    )


@router.post("/face/challenge")
async def issue_liveness_challenge(
    purpose: str = Form("face_reauth"),
    device_id: str = Form(...),
    current_user: FirebaseUser = Depends(require_firebase_user),
) -> dict:
    try:
        challenge = create_liveness_challenge(
            uid=current_user.uid,
            device_id=device_id,
            purpose=purpose,
        )
    except LivenessChallengeError as exc:
        status_code = (
            status.HTTP_429_TOO_MANY_REQUESTS
            if exc.reason == "liveness_rate_limited"
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=status_code, detail=exc.reason) from exc
    return {
        "challengeId": challenge.challenge_id,
        "actions": list(challenge.actions),
        "expiresAt": challenge.expires_at.astimezone(timezone.utc).isoformat(),
    }


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
    purpose: str = Form("face_reauth"),
    device_id: str | None = Form(None),
    challenge_id: str = Form(...),
    challenge_response: str = Form(...),
    evidence_frames: list[UploadFile] = File(...),
    current_user: FirebaseUser = Depends(require_firebase_user),
) -> dict:
    live_file = _pick_live_file(live=live, live_frame=live_frame)

    try:
        evidence_result = await _verify_liveness_evidence(
            challenge_id=challenge_id,
            challenge_response=challenge_response,
            evidence_frames=evidence_frames,
            current_user=current_user,
            purpose=purpose,
            device_id=(device_id or "").strip(),
        )
        if isinstance(evidence_result, dict):
            return evidence_result

        result = await _verify_uploaded_pair(selfie=selfie, live_file=live_file)
        if isinstance(result, dict):
            record_liveness_failure(
                current_user.uid,
                (device_id or "").strip(),
                str(result.get("reason") or "face_verification_failed"),
            )
            return result
        if not _evidence_matches_face(
            evidence_result,
            result.live_embedding,
            result.threshold,
        ):
            record_liveness_failure(
                current_user.uid,
                (device_id or "").strip(),
                "challenge_identity_mismatch",
            )
            return {"success": False, "reason": "challenge_identity_mismatch"}

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

        response = {
            "success": enrollment.enrolled,
            "similarity": result.similarity,
            "threshold": result.threshold,
            "modelVersion": enrollment.model_version,
        }
        if enrollment.enrolled and purpose == VIDEO_MATCHING_PURPOSE:
            session = issue_face_session(
                uid=current_user.uid,
                similarity=result.similarity,
                threshold=result.threshold,
                purpose=purpose,
                device_id=device_id,
            )
            response["sessionId"] = session.session_id
            response["expiresAt"] = session.expires_at.astimezone(
                timezone.utc
            ).isoformat() if session.expires_at else None
        if enrollment.enrolled:
            reset_liveness_failures(current_user.uid, (device_id or "").strip())
        return response
    finally:
        await selfie.close()
        if live is not None:
            await live.close()
        if live_frame is not None and live_frame is not live:
            await live_frame.close()
        for evidence_frame in evidence_frames:
            await evidence_frame.close()


@router.post("/face/reauth")
async def reauth_face(
    live: UploadFile | None = File(None),
    live_frame: UploadFile | None = File(None),
    purpose: str = Form("face_reauth"),
    device_id: str | None = Form(None),
    challenge_id: str = Form(...),
    challenge_response: str = Form(...),
    evidence_frames: list[UploadFile] = File(...),
    current_user: FirebaseUser = Depends(require_firebase_user),
) -> dict:
    live_file = _pick_live_file(live=live, live_frame=live_frame)

    try:
        evidence_result = await _verify_liveness_evidence(
            challenge_id=challenge_id,
            challenge_response=challenge_response,
            evidence_frames=evidence_frames,
            current_user=current_user,
            purpose=purpose,
            device_id=(device_id or "").strip(),
        )
        if isinstance(evidence_result, dict):
            return evidence_result

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
        settings = get_settings()
        if not _evidence_matches_face(
            evidence_result,
            live_embedding,
            settings.reauth_similarity_threshold,
        ):
            record_liveness_failure(
                current_user.uid,
                (device_id or "").strip(),
                "challenge_identity_mismatch",
            )
            return {"success": False, "reason": "challenge_identity_mismatch"}

        try:
            result = reauthenticate_face(
                uid=current_user.uid,
                live_embedding=live_embedding,
                purpose=purpose,
                device_id=device_id,
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
            reset_liveness_failures(
                current_user.uid,
                (device_id or "").strip(),
            )
        else:
            record_liveness_failure(
                current_user.uid,
                (device_id or "").strip(),
                result.reason or "face_verification_failed",
            )
        return response
    finally:
        if live is not None:
            await live.close()
        if live_frame is not None and live_frame is not live:
            await live_frame.close()
        for evidence_frame in evidence_frames:
            await evidence_frame.close()
