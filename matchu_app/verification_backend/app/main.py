from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.face_verify import router as face_verify_router
from app.core.config import get_settings
from app.services.face_embedding import get_face_engine_error, warmup_face_engine

settings = get_settings()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
)

allow_all = settings.cors_allow_origins == ("*",)
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_allow_origins),
    allow_credentials=not allow_all,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Keep original endpoint and add /v1 alias for future client integration.
app.include_router(face_verify_router)
app.include_router(face_verify_router, prefix="/v1")


@app.on_event("startup")
def startup_warmup() -> None:
    if warmup_face_engine():
        logging.getLogger(__name__).info("Face engine warmup succeeded.")
        return
    logging.getLogger(__name__).warning(
        "Face engine warmup failed: %s",
        get_face_engine_error() or "unknown_error",
    )


@app.get("/", tags=["System"])
def root() -> dict:
    return {
        "service": settings.app_name,
        "version": settings.app_version,
        "status": "ok",
    }


@app.get("/health", tags=["System"])
def health() -> dict:
    return {"status": "ok"}


@app.get("/health/engine", tags=["System"])
def health_engine() -> dict:
    available = warmup_face_engine()
    return {
        "status": "ok" if available else "degraded",
        "engineAvailable": available,
        "error": get_face_engine_error(),
    }
