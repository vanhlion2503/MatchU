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


def _key_version() -> str:
    return os.getenv("FACE_TEMPLATE_KEY_VERSION", "v1").strip() or "v1"


@lru_cache(maxsize=1)
def _encryption_keys() -> dict[str, bytes]:
    """Loads a versioned keyring while remaining compatible with the v1 secret."""
    raw_keyring = os.getenv("FACE_TEMPLATE_ENCRYPTION_KEYS_B64", "").strip()
    keys: dict[str, bytes] = {}
    if raw_keyring:
        try:
            payload = json.loads(raw_keyring)
        except json.JSONDecodeError as exc:
            raise FaceTemplateCryptoError(
                "FACE_TEMPLATE_ENCRYPTION_KEYS_B64 must be a JSON object."
            ) from exc
        if not isinstance(payload, dict):
            raise FaceTemplateCryptoError(
                "FACE_TEMPLATE_ENCRYPTION_KEYS_B64 must be a JSON object."
            )
        for version, raw_key in payload.items():
            clean_version = str(version).strip()
            if clean_version:
                keys[clean_version] = _decode_key(str(raw_key))

    legacy = os.getenv("FACE_TEMPLATE_ENCRYPTION_KEY_B64", "").strip()
    if legacy:
        legacy_key = _decode_key(legacy)
        keys.setdefault("v1", legacy_key)
        keys.setdefault(_key_version(), legacy_key)
    if not keys:
        raise FaceTemplateCryptoError(
            "A face template encryption key is required."
        )
    return keys


def _encryption_key(key_version: str) -> bytes:
    key = _encryption_keys().get(key_version)
    if key is None:
        raise FaceTemplateCryptoError(
            f"Face template key version is unavailable: {key_version}."
        )
    return key


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

    ciphertext = AESGCM(_encryption_key(key_version)).encrypt(
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
        plaintext = AESGCM(_encryption_key(key_version)).decrypt(
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
