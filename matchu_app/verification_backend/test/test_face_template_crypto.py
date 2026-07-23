from __future__ import annotations

import base64
import json
import os
import unittest
from unittest.mock import patch

import numpy as np

try:
    from app.services import face_template_crypto
except ModuleNotFoundError as import_error:
    face_template_crypto = None
    CRYPTO_IMPORT_ERROR = import_error
else:
    CRYPTO_IMPORT_ERROR = None


def encoded_key(value: int) -> str:
    return base64.b64encode(bytes([value]) * 32).decode("ascii")


@unittest.skipIf(
    face_template_crypto is None,
    f"cryptography dependency is unavailable: {CRYPTO_IMPORT_ERROR}",
)
class FaceTemplateCryptoTest(unittest.TestCase):
    def tearDown(self) -> None:
        face_template_crypto._encryption_keys.cache_clear()

    def test_decrypts_template_with_its_key_version(self) -> None:
        keyring = json.dumps({"v1": encoded_key(1), "v2": encoded_key(2)})
        vector = np.asarray([0.1, 0.2, 0.3], dtype=np.float32)

        with patch.dict(
            os.environ,
            {
                "FACE_TEMPLATE_ENCRYPTION_KEYS_B64": keyring,
                "FACE_TEMPLATE_KEY_VERSION": "v1",
            },
            clear=False,
        ):
            face_template_crypto._encryption_keys.cache_clear()
            encrypted = face_template_crypto.encrypt_embedding(
                uid="user-a",
                embedding=vector,
                model_version="model-a",
            )

        with patch.dict(
            os.environ,
            {
                "FACE_TEMPLATE_ENCRYPTION_KEYS_B64": keyring,
                "FACE_TEMPLATE_KEY_VERSION": "v2",
            },
            clear=False,
        ):
            face_template_crypto._encryption_keys.cache_clear()
            decrypted = face_template_crypto.decrypt_embedding(
                uid="user-a",
                encrypted_template=encrypted,
                model_version="model-a",
            )

        np.testing.assert_allclose(decrypted, vector)

    def test_legacy_secret_remains_compatible(self) -> None:
        vector = np.asarray([0.4, 0.5], dtype=np.float32)
        with patch.dict(
            os.environ,
            {
                "FACE_TEMPLATE_ENCRYPTION_KEY_B64": encoded_key(3),
                "FACE_TEMPLATE_KEY_VERSION": "legacy-v3",
                "FACE_TEMPLATE_ENCRYPTION_KEYS_B64": "",
            },
            clear=False,
        ):
            face_template_crypto._encryption_keys.cache_clear()
            encrypted = face_template_crypto.encrypt_embedding(
                uid="user-b",
                embedding=vector,
                model_version="model-b",
            )
            decrypted = face_template_crypto.decrypt_embedding(
                uid="user-b",
                encrypted_template=encrypted,
                model_version="model-b",
            )

        self.assertEqual(encrypted["keyVersion"], "legacy-v3")
        np.testing.assert_allclose(decrypted, vector)


if __name__ == "__main__":
    unittest.main()
