from __future__ import annotations

import base64
import json
import os
from functools import lru_cache

import numpy as np
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class FaceTemplateCryptoError(RuntimeError):
    pass


def _decode_key(raw: str) -> bytes:
    value = raw.strip()
    try:
        key = base64.b64decode(value, validate=True)
    except Exception as exc:
        raise FaceTemplateCryptoError(
            "FACE_TEMPLATE_ENCRYPTION_KEY_B64 must be valid base64."
        ) from exc

    if len(key) != 32:
        raise FaceTemplateCryptoError(
            "FACE_TEMPLATE_ENCRYPTION_KEY_B64 must decode to 32 bytes."
        )
    return key


@lru_cache(maxsize=1)
def _encryption_key() -> bytes:
    raw = os.getenv("FACE_TEMPLATE_ENCRYPTION_KEY_B64", "")
    if not raw.strip():
        raise FaceTemplateCryptoError(
            "FACE_TEMPLATE_ENCRYPTION_KEY_B64 is required for biometric storage."
        )
    return _decode_key(raw)


def _key_version() -> str:
    return os.getenv("FACE_TEMPLATE_KEY_VERSION", "v1").strip() or "v1"


def _aad(uid: str, model_version: str, key_version: str) -> bytes:
    return f"matchu-face-template:{uid}:{model_version}:{key_version}".encode(
        "utf-8"
    )


def encrypt_embedding(
    *,
    uid: str,
    embedding: np.ndarray,
    model_version: str,
) -> dict:
    vector = np.asarray(embedding, dtype=np.float32).reshape(-1)
    if vector.size == 0:
        raise FaceTemplateCryptoError("Cannot encrypt an empty face template.")

    key_version = _key_version()
    nonce = os.urandom(12)
    payload = json.dumps(
        {
            "dtype": "float32",
            "shape": [int(vector.size)],
            "embedding": base64.b64encode(vector.tobytes()).decode("ascii"),
        },
        separators=(",", ":"),
    ).encode("utf-8")

    ciphertext = AESGCM(_encryption_key()).encrypt(
        nonce,
        payload,
        _aad(uid, model_version, key_version),
    )

    return {
        "algorithm": "AES-256-GCM",
        "keyVersion": key_version,
        "nonce": base64.b64encode(nonce).decode("ascii"),
        "ciphertext": base64.b64encode(ciphertext).decode("ascii"),
    }


def decrypt_embedding(
    *,
    uid: str,
    encrypted_template: dict,
    model_version: str,
) -> np.ndarray:
    key_version = str(encrypted_template.get("keyVersion") or "")
    nonce_b64 = str(encrypted_template.get("nonce") or "")
    ciphertext_b64 = str(encrypted_template.get("ciphertext") or "")
    if not key_version or not nonce_b64 or not ciphertext_b64:
        raise FaceTemplateCryptoError("Encrypted face template is incomplete.")

    try:
        nonce = base64.b64decode(nonce_b64, validate=True)
        ciphertext = base64.b64decode(ciphertext_b64, validate=True)
    except Exception as exc:
        raise FaceTemplateCryptoError("Encrypted face template is malformed.") from exc

    try:
        plaintext = AESGCM(_encryption_key()).decrypt(
            nonce,
            ciphertext,
            _aad(uid, model_version, key_version),
        )
        payload = json.loads(plaintext.decode("utf-8"))
        raw_embedding = base64.b64decode(str(payload["embedding"]), validate=True)
        vector = np.frombuffer(raw_embedding, dtype=np.float32).copy()
    except Exception as exc:
        raise FaceTemplateCryptoError("Cannot decrypt face template.") from exc

    if vector.size == 0:
        raise FaceTemplateCryptoError("Face template is empty.")
    return vector
