from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


def _env_int(name: str, default: int, min_value: int | None = None) -> int:
    raw = os.getenv(name)
    if raw is None:
        value = default
    else:
        try:
            value = int(raw)
        except ValueError:
            value = default

    if min_value is not None and value < min_value:
        return min_value
    return value


def _env_float(name: str, default: float, min_value: float | None = None, max_value: float | None = None) -> float:
    raw = os.getenv(name)
    if raw is None:
        value = default
    else:
        try:
            value = float(raw)
        except ValueError:
            value = default

    if min_value is not None and value < min_value:
        value = min_value
    if max_value is not None and value > max_value:
        value = max_value
    return value


@dataclass(frozen=True)
class Settings:
    app_name: str
    app_version: str
    similarity_threshold: float
    max_upload_size_mb: int
    insightface_model_name: str
    insightface_ctx_id: int
    insightface_det_size: int
    cors_allow_origins: tuple[str, ...]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    raw_origins = os.getenv("CORS_ALLOW_ORIGINS", "*")
    cors_allow_origins = tuple(origin.strip() for origin in raw_origins.split(",") if origin.strip())
    if not cors_allow_origins:
        cors_allow_origins = ("*",)

    return Settings(
        app_name=os.getenv("APP_NAME", "MatchU Verification Backend"),
        app_version=os.getenv("APP_VERSION", "0.1.0"),
        similarity_threshold=_env_float("SIMILARITY_THRESHOLD", 0.65, min_value=0.0, max_value=1.0),
        max_upload_size_mb=_env_int("MAX_UPLOAD_SIZE_MB", 10, min_value=1),
        insightface_model_name=os.getenv("INSIGHTFACE_MODEL_NAME", "buffalo_l"),
        insightface_ctx_id=_env_int("INSIGHTFACE_CTX_ID", -1),
        insightface_det_size=_env_int("INSIGHTFACE_DET_SIZE", 640, min_value=64),
        cors_allow_origins=cors_allow_origins,
    )
