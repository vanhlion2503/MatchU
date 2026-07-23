from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from app.services.template_update_authorization import (
    TemplateUpdateAuthorizationError,
    validate_template_update_authorization_payload,
)


class TemplateUpdateAuthorizationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 7, 23, tzinfo=timezone.utc)
        self.payload = {
            "uid": "user-a",
            "deviceId": "device-a",
            "purpose": "face_template_update",
            "method": "chat_pin",
            "status": "valid",
            "expiresAt": self.now + timedelta(minutes=5),
        }

    def test_accepts_fresh_device_bound_authorization(self) -> None:
        validate_template_update_authorization_payload(
            data=self.payload,
            uid="user-a",
            device_id="device-a",
            now=self.now,
        )

    def test_rejects_wrong_device_or_expired_authorization(self) -> None:
        with self.assertRaisesRegex(
            TemplateUpdateAuthorizationError,
            "template_update_authorization_invalid",
        ):
            validate_template_update_authorization_payload(
                data=self.payload,
                uid="user-a",
                device_id="device-b",
                now=self.now,
            )

        expired = {
            **self.payload,
            "expiresAt": self.now - timedelta(seconds=1),
        }
        with self.assertRaisesRegex(
            TemplateUpdateAuthorizationError,
            "template_update_authorization_invalid",
        ):
            validate_template_update_authorization_payload(
                data=expired,
                uid="user-a",
                device_id="device-a",
                now=self.now,
            )


if __name__ == "__main__":
    unittest.main()
