from __future__ import annotations

from datetime import datetime


ALLOWED_PURPOSES = {"face_reauth", "video_matching"}


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
    if (
        len(expected) != 3
        or expected[0] != "center"
        or set(expected[1:]) != {"turn_left", "turn_right"}
        or tuple(response_actions) != expected
    ):
        raise LivenessChallengeError("challenge_response_mismatch")
    return expected


def validate_pose_evidence(actions: tuple[str, ...], yaws: list[float]) -> None:
    if len(actions) != 3 or len(yaws) != 3:
        raise LivenessChallengeError("challenge_evidence_incomplete")

    center_yaw = yaws[0]
    if abs(center_yaw) > 14.0:
        raise LivenessChallengeError("challenge_center_pose_invalid")

    for action, yaw in zip(actions[1:], yaws[1:]):
        if action == "turn_left" and yaw > -10.0:
            raise LivenessChallengeError("challenge_turn_pose_invalid")
        if action == "turn_right" and yaw < 10.0:
            raise LivenessChallengeError("challenge_turn_pose_invalid")

    first_turn, second_turn = yaws[1], yaws[2]
    if abs(first_turn - second_turn) < 22.0:
        raise LivenessChallengeError("challenge_turn_sequence_invalid")
