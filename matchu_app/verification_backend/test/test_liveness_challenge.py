from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from app.services.liveness_validation import (
    LivenessChallengeError,
    validate_challenge_payload,
    validate_pose_evidence,
)


class LivenessChallengeValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 7, 23, tzinfo=timezone.utc)
        self.data = {
            "uid": "user-a",
            "deviceId": "device-a",
            "purpose": "video_matching",
            "status": "pending",
            "actions": ["center", "turn_left", "turn_right"],
            "expiresAt": self.now + timedelta(minutes=1),
        }

    def test_accepts_matching_unexpired_challenge(self) -> None:
        actions = validate_challenge_payload(
            data=self.data,
            uid="user-a",
            device_id="device-a",
            purpose="video_matching",
            response_actions=["center", "turn_left", "turn_right"],
            now=self.now,
        )
        self.assertEqual(
            actions,
            ("center", "turn_left", "turn_right"),
        )

    def test_rejects_reordered_response(self) -> None:
        with self.assertRaisesRegex(
            LivenessChallengeError,
            "challenge_response_mismatch",
        ):
            validate_challenge_payload(
                data=self.data,
                uid="user-a",
                device_id="device-a",
                purpose="video_matching",
                response_actions=["center", "turn_right", "turn_left"],
                now=self.now,
            )

    def test_pose_evidence_requires_center_and_opposite_turns(self) -> None:
        actions = ("center", "turn_left", "turn_right")
        validate_pose_evidence(actions, [2.0, -18.0, 19.0])
        with self.assertRaisesRegex(
            LivenessChallengeError,
            "challenge_turn_pose_invalid",
        ):
            validate_pose_evidence(actions, [2.0, 18.0, 20.0])

    def test_pose_evidence_must_follow_requested_turn_order(self) -> None:
        actions = ("center", "turn_right", "turn_left")
        validate_pose_evidence(actions, [1.0, 17.0, -18.0])
        with self.assertRaisesRegex(
            LivenessChallengeError,
            "challenge_turn_pose_invalid",
        ):
            validate_pose_evidence(actions, [1.0, -18.0, 17.0])

    def test_accepts_v2_challenge_with_blink(self) -> None:
        data = {
            **self.data,
            "livenessVersion": 2,
            "actions": ["center", "blink", "turn_right", "turn_left"],
        }
        actions = validate_challenge_payload(
            data=data,
            uid="user-a",
            device_id="device-a",
            purpose="video_matching",
            response_actions=["center", "blink", "turn_right", "turn_left"],
            now=self.now,
        )
        self.assertEqual(
            actions,
            ("center", "blink", "turn_right", "turn_left"),
        )
        validate_pose_evidence(actions, [1.0, 2.0, -18.0, 19.0])

    def test_v2_blink_evidence_must_remain_centered(self) -> None:
        actions = ("center", "blink", "turn_left", "turn_right")
        with self.assertRaisesRegex(
            LivenessChallengeError,
            "challenge_blink_pose_invalid",
        ):
            validate_pose_evidence(actions, [1.0, 20.0, 18.0, -19.0])

    def test_v2_turns_use_front_camera_user_directions(self) -> None:
        actions = ("center", "blink", "turn_left", "turn_right")
        validate_pose_evidence(actions, [1.0, 2.0, 18.0, -19.0])
        with self.assertRaisesRegex(
            LivenessChallengeError,
            "challenge_turn_pose_invalid",
        ):
            validate_pose_evidence(actions, [1.0, 2.0, -18.0, 19.0])


if __name__ == "__main__":
    unittest.main()
