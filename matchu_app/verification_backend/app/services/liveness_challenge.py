from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from random import SystemRandom

from firebase_admin import firestore
from google.cloud.firestore_v1.transaction import transactional

from app.services.firebase_identity import ensure_firebase_app
from app.services.liveness_validation import (
    LivenessChallengeError,
    normalize_purpose,
    validate_challenge_payload,
    validate_pose_evidence,
)


CHALLENGE_TTL = timedelta(minutes=2)
FAILURE_WINDOW = timedelta(minutes=3)
FAILURE_LIMIT = 5
BLOCK_DURATION = timedelta(minutes=30)
_random = SystemRandom()


@dataclass(frozen=True)
class LivenessChallenge:
    challenge_id: str
    actions: tuple[str, ...]
    expires_at: datetime


def _db() -> firestore.Client:
    ensure_firebase_app()
    return firestore.client()


def _rate_limit_id(uid: str, device_id: str) -> str:
    value = f"{uid}:{device_id}".encode("utf-8")
    return hashlib.sha256(value).hexdigest()


def assert_not_rate_limited(uid: str, device_id: str, now: datetime) -> None:
    ref = _db().collection("faceLivenessRateLimits").document(
        _rate_limit_id(uid, device_id)
    )
    snapshot = ref.get()
    if not snapshot.exists:
        return
    blocked_until = (snapshot.to_dict() or {}).get("blockedUntil")
    if isinstance(blocked_until, datetime) and blocked_until > now:
        raise LivenessChallengeError("liveness_rate_limited")


def create_liveness_challenge(
    *,
    uid: str,
    device_id: str,
    purpose: str,
    liveness_version: int = 1,
) -> LivenessChallenge:
    clean_device_id = (device_id or "").strip()
    if not clean_device_id:
        raise LivenessChallengeError("device_id_required")

    now = datetime.now(timezone.utc)
    assert_not_rate_limited(uid, clean_device_id, now)
    turns = ["turn_left", "turn_right"]
    _random.shuffle(turns)
    # Keep v1 available for already-released clients. Clients advertising v2
    # receive the additional blink action.
    actions = (
        ("center", "blink", *turns)
        if liveness_version >= 2
        else ("center", *turns)
    )
    expires_at = now + CHALLENGE_TTL
    challenge_id = secrets.token_urlsafe(24)
    _db().collection("faceLivenessChallenges").document(challenge_id).set(
        {
            "uid": uid,
            "deviceId": clean_device_id,
            "purpose": normalize_purpose(purpose),
            "livenessVersion": 2 if liveness_version >= 2 else 1,
            "actions": list(actions),
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "expiresAt": expires_at,
        }
    )
    return LivenessChallenge(
        challenge_id=challenge_id,
        actions=actions,
        expires_at=expires_at,
    )


def consume_liveness_challenge(
    *,
    challenge_id: str,
    uid: str,
    device_id: str,
    purpose: str,
    response_actions: list[str],
) -> tuple[str, ...]:
    db = _db()
    ref = db.collection("faceLivenessChallenges").document(challenge_id)
    transaction = db.transaction()

    @transactional
    def consume(tx: firestore.Transaction) -> tuple[str, ...]:
        snapshot = ref.get(transaction=tx)
        actions = validate_challenge_payload(
            data=snapshot.to_dict() if snapshot.exists else None,
            uid=uid,
            device_id=device_id,
            purpose=purpose,
            response_actions=response_actions,
            now=datetime.now(timezone.utc),
        )
        tx.update(
            ref,
            {
                "status": "consumed",
                "consumedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        return actions

    return consume(transaction)


def record_liveness_failure(uid: str, device_id: str, reason: str) -> None:
    if not device_id:
        return
    db = _db()
    ref = db.collection("faceLivenessRateLimits").document(
        _rate_limit_id(uid, device_id)
    )
    transaction = db.transaction()

    @transactional
    def update_failure(tx: firestore.Transaction) -> None:
        now = datetime.now(timezone.utc)
        snapshot = ref.get(transaction=tx)
        data = snapshot.to_dict() if snapshot.exists else {}
        window_started_at = data.get("windowStartedAt")
        inside_window = (
            isinstance(window_started_at, datetime)
            and now - window_started_at <= FAILURE_WINDOW
        )
        failure_count = int(data.get("failureCount") or 0) + 1 if inside_window else 1
        next_window = window_started_at if inside_window else now
        blocked_until = now + BLOCK_DURATION if failure_count >= FAILURE_LIMIT else None
        tx.set(
            ref,
            {
                "uid": uid,
                "deviceIdHash": _rate_limit_id(uid, device_id),
                "failureCount": failure_count,
                "windowStartedAt": next_window,
                "blockedUntil": blocked_until,
                "lastFailureReason": reason[:80],
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    update_failure(transaction)


def reset_liveness_failures(uid: str, device_id: str) -> None:
    if not device_id:
        return
    _db().collection("faceLivenessRateLimits").document(
        _rate_limit_id(uid, device_id)
    ).set(
        {
            "failureCount": 0,
            "windowStartedAt": None,
            "blockedUntil": None,
            "lastFailureReason": None,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def reserve_evidence_fingerprints(
    *,
    uid: str,
    challenge_id: str,
    fingerprints: list[str],
) -> None:
    if len(fingerprints) not in {3, 4} or len(set(fingerprints)) != len(
        fingerprints
    ):
        raise LivenessChallengeError("challenge_replay_detected")

    db = _db()
    refs = [
        db.collection("faceLivenessEvidenceFingerprints").document(
            hashlib.sha256(f"{uid}:{fingerprint}".encode("utf-8")).hexdigest()
        )
        for fingerprint in fingerprints
    ]
    transaction = db.transaction()

    @transactional
    def reserve(tx: firestore.Transaction) -> None:
        snapshots = [ref.get(transaction=tx) for ref in refs]
        if any(snapshot.exists for snapshot in snapshots):
            raise LivenessChallengeError("challenge_replay_detected")
        for ref, fingerprint in zip(refs, fingerprints):
            tx.set(
                ref,
                {
                    "uid": uid,
                    "challengeId": challenge_id,
                    "fingerprint": fingerprint,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "expiresAt": datetime.now(timezone.utc) + timedelta(days=30),
                },
            )

    reserve(transaction)


__all__ = [
    "LivenessChallenge",
    "LivenessChallengeError",
    "consume_liveness_challenge",
    "create_liveness_challenge",
    "normalize_purpose",
    "record_liveness_failure",
    "reserve_evidence_fingerprints",
    "reset_liveness_failures",
    "validate_challenge_payload",
    "validate_pose_evidence",
]
