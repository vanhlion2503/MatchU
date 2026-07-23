from __future__ import annotations

import logging
import hashlib
import time
from threading import Lock
from typing import Any

import numpy as np
from dataclasses import dataclass

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_cv2_import_error: str | None = None
try:
    import cv2
except Exception as exc:  # pragma: no cover - defensive import guard
    cv2 = None
    _cv2_import_error = f"{type(exc).__name__}: {exc}"

_insightface_import_error: str | None = None
try:
    from insightface.app import FaceAnalysis
except Exception as exc:  # pragma: no cover - defensive import guard
    FaceAnalysis = None
    _insightface_import_error = f"{type(exc).__name__}: {exc}"


_face_app: Any | None = None
_face_app_lock = Lock()
_face_app_error: str | None = None
_face_app_last_attempt_mono: float = 0.0
_init_retry_interval_seconds = 15.0


@dataclass(frozen=True)
class FaceObservation:
    embedding: np.ndarray
    pitch: float
    yaw: float
    roll: float
    face_area_ratio: float
    perceptual_fingerprint: str


def _set_face_app_error(error: str | None) -> None:
    global _face_app_error
    global _face_app_last_attempt_mono
    _face_app_error = error
    _face_app_last_attempt_mono = time.monotonic()


def get_face_engine_error() -> str | None:
    if _face_app_error:
        return _face_app_error
    if _cv2_import_error:
        return _cv2_import_error
    if _insightface_import_error:
        return _insightface_import_error
    return None


def warmup_face_engine() -> bool:
    if cv2 is None:
        return False
    return _get_face_app() is not None


def _get_face_app() -> Any | None:
    global _face_app

    if cv2 is None:
        _set_face_app_error(_cv2_import_error or "opencv_import_error")
        return None

    if _face_app is not None:
        return _face_app
    now = time.monotonic()
    if (
        _face_app_error is not None
        and now - _face_app_last_attempt_mono < _init_retry_interval_seconds
    ):
        return None

    with _face_app_lock:
        if _face_app is not None:
            return _face_app

        now = time.monotonic()
        if (
            _face_app_error is not None
            and now - _face_app_last_attempt_mono < _init_retry_interval_seconds
        ):
            return None

        if FaceAnalysis is None:
            error = _insightface_import_error or "insightface_import_error"
            _set_face_app_error(error)
            logger.error("InsightFace import failed: %s", error)
            return None

        settings = get_settings()

        try:
            model = FaceAnalysis(name=settings.insightface_model_name)
            model.prepare(
                ctx_id=settings.insightface_ctx_id,
                det_size=(settings.insightface_det_size, settings.insightface_det_size),
            )
            _face_app = model
            _set_face_app_error(None)
        except Exception as exc:  # pragma: no cover - depends on runtime env
            _set_face_app_error(f"{type(exc).__name__}: {exc}")
            logger.exception("Cannot initialize face engine: %s", exc)
            return None

    return _face_app


def _face_area(face: Any) -> float:
    bbox = getattr(face, "bbox", None)
    if bbox is None or len(bbox) < 4:
        return 0.0

    width = max(0.0, float(bbox[2] - bbox[0]))
    height = max(0.0, float(bbox[3] - bbox[1]))
    return width * height


def _perceptual_fingerprint(image: np.ndarray) -> str:
    """Small dHash used to reject exact/near-identical evidence replays."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    resized = cv2.resize(gray, (9, 8), interpolation=cv2.INTER_AREA)
    bits = resized[:, 1:] > resized[:, :-1]
    packed = np.packbits(bits.reshape(-1).astype(np.uint8)).tobytes()
    return hashlib.sha256(packed).hexdigest()


def extract_face_observation(
    image_bytes: bytes,
) -> tuple[FaceObservation | None, str | None]:
    """
    Returns:
    - (embedding, None) on success
    - (None, error_code) on failure

    error_code in:
    - engine_unavailable
    - invalid_image
    - face_not_detected
    - multiple_faces_detected
    - image_too_dark
    - image_too_bright
    - image_too_blurry
    - face_too_small
    """
    if cv2 is None:
        return None, "engine_unavailable"

    face_app = _get_face_app()
    if face_app is None:
        return None, "engine_unavailable"

    if not image_bytes:
        return None, "invalid_image"

    img = cv2.imdecode(np.frombuffer(image_bytes, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        return None, "invalid_image"

    height, width = img.shape[:2]
    if height < 160 or width < 160 or height * width > 24_000_000:
        return None, "invalid_image"
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    brightness = float(np.mean(gray))
    if brightness < 20.0:
        return None, "image_too_dark"
    if brightness > 240.0:
        return None, "image_too_bright"
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    if sharpness < 20.0:
        return None, "image_too_blurry"

    try:
        faces = face_app.get(img)
    except Exception as exc:  # pragma: no cover - depends on runtime env
        _set_face_app_error(f"inference_error:{type(exc).__name__}: {exc}")
        logger.exception("Face inference failed: %s", exc)
        return None, "engine_unavailable"

    if not faces:
        return None, "face_not_detected"
    if len(faces) != 1:
        return None, "multiple_faces_detected"

    primary_face = faces[0]
    face_area_ratio = _face_area(primary_face) / float(width * height)
    if face_area_ratio < 0.03:
        return None, "face_too_small"
    embedding = getattr(primary_face, "embedding", None)
    if embedding is None:
        return None, "face_not_detected"

    pose = getattr(primary_face, "pose", None)
    pitch = float(pose[0]) if pose is not None and len(pose) >= 3 else 0.0
    yaw = float(pose[1]) if pose is not None and len(pose) >= 2 else 0.0
    roll = float(pose[2]) if pose is not None and len(pose) >= 3 else 0.0
    return FaceObservation(
        embedding=np.asarray(embedding, dtype=np.float32),
        pitch=pitch,
        yaw=yaw,
        roll=roll,
        face_area_ratio=face_area_ratio,
        perceptual_fingerprint=_perceptual_fingerprint(img),
    ), None


def extract_embedding(image_bytes: bytes) -> tuple[np.ndarray | None, str | None]:
    observation, error = extract_face_observation(image_bytes)
    return (observation.embedding if observation is not None else None), error
