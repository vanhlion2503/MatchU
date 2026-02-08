from __future__ import annotations

import logging
import time
from threading import Lock
from typing import Any

import numpy as np

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


def extract_embedding(image_bytes: bytes) -> tuple[np.ndarray | None, str | None]:
    """
    Returns:
    - (embedding, None) on success
    - (None, error_code) on failure

    error_code in:
    - engine_unavailable
    - invalid_image
    - face_not_detected
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

    try:
        faces = face_app.get(img)
    except Exception as exc:  # pragma: no cover - depends on runtime env
        _set_face_app_error(f"inference_error:{type(exc).__name__}: {exc}")
        logger.exception("Face inference failed: %s", exc)
        return None, "engine_unavailable"

    if not faces:
        return None, "face_not_detected"

    primary_face = max(faces, key=_face_area)
    embedding = getattr(primary_face, "embedding", None)
    if embedding is None:
        return None, "face_not_detected"

    return np.asarray(embedding, dtype=np.float32), None
