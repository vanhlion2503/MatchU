from __future__ import annotations

import logging
from datetime import datetime


ALLOWED_PURPOSES = {"face_reauth", "video_matching"}
logger = logging.getLogger(__name__)


class LivenessChallengeError(ValueError):
    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


def normalize_purpose(value: str | None) -> str:
    return value if value in ALLOWED_PURPOSES else "face_reauth"


def validate_challenge_payload(
    *,
    data: dict | None,
    uid: str,
    device_id: str,
    purpose: str,
    response_actions: list[str],
    now: datetime,
) -> tuple[str, ...]:
    if not data:
        raise LivenessChallengeError("challenge_not_found")
    expires_at = data.get("expiresAt")
    if (
        data.get("uid") != uid
        or data.get("deviceId") != device_id
        or data.get("purpose") != normalize_purpose(purpose)
        or data.get("status") != "pending"
        or not isinstance(expires_at, datetime)
        or expires_at <= now
    ):
        raise LivenessChallengeError("challenge_invalid")

    expected = tuple(data.get("actions") or ())
    is_legacy_sequence = (
        len(expected) == 3
        and expected[0] == "center"
        and set(expected[1:]) == {"turn_left", "turn_right"}
    )
    is_blink_sequence = (
        len(expected) == 4
        and expected[:2] == ("center", "blink")
        and set(expected[2:]) == {"turn_left", "turn_right"}
    )
    if (
        not (is_legacy_sequence or is_blink_sequence)
        or tuple(response_actions) != expected
    ):
        raise LivenessChallengeError("challenge_response_mismatch")
    return expected


def validate_pose_evidence(actions: tuple[str, ...], yaws: list[float]) -> None:
    if len(actions) not in {3, 4} or len(yaws) != len(actions):
        raise LivenessChallengeError("challenge_evidence_incomplete")

    if actions[0] != "center" or abs(yaws[0]) > 14.0:
        raise LivenessChallengeError("challenge_center_pose_invalid")

    if "blink" in actions:
        blink_index = actions.index("blink")
        if blink_index != 1 or abs(yaws[blink_index]) > 14.0:
            raise LivenessChallengeError("challenge_blink_pose_invalid")

    # V2 uses the user's left/right in a mirrored front-camera preview. The
    # captured JPEG processed by InsightFace has the opposite yaw sign from the
    # ML Kit preview. Keep the legacy convention for already-released clients.
    uses_front_camera_user_directions = "blink" in actions

    turn_yaws: list[float] = []
    for action, yaw in zip(actions, yaws):
        is_invalid_turn = (
            action == "turn_left"
            and (
                yaw < 10.0
                if uses_front_camera_user_directions
                else yaw > -10.0
            )
        ) or (
            action == "turn_right"
            and (
                yaw > -10.0
                if uses_front_camera_user_directions
                else yaw < 10.0
            )
        )
        if is_invalid_turn:
            # Pose values help diagnose camera-coordinate issues without
            # recording a UID, image, template, or other biometric data.
            logger.info(
                "Liveness turn rejected: protocol=%s action=%s yaw=%.2f",
                "v2" if uses_front_camera_user_directions else "v1",
                action,
                yaw,
            )
            raise LivenessChallengeError("challenge_turn_pose_invalid")
        if action in {"turn_left", "turn_right"}:
            turn_yaws.append(yaw)

    if len(turn_yaws) != 2:
        raise LivenessChallengeError("challenge_evidence_incomplete")
    first_turn, second_turn = turn_yaws
    if abs(first_turn - second_turn) < 22.0:
        raise LivenessChallengeError("challenge_turn_sequence_invalid")
