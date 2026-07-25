const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

const { admin, db } = require("../shared/firebase");

const QUEUE_COLLECTION = "tempChatMatchingQueue";
const TEMP_CHAT_DURATION_MS = 7 * 60 * 1000;
const VIDEO_CHAT_DURATION_MS = 8 * 60 * 1000;
const VIDEO_CAMERA_LOCK_MS = 90 * 1000;
const QUEUE_TTL_MS = 90 * 1000;
const DAILY_MATCH_LIMIT = 10;
const MATCH_SCAN_LIMIT = 50;
const MIN_TEMP_CHAT_REPUTATION = 80;
const MIN_VIDEO_REPUTATION = 90;
const VIDEO_MATCH_GEM_COST = 1;
const ROOM_EXTENSION_GEM_COST = 1;
const ROOM_EXTENSION_DURATION_MS = 5 * 60 * 1000;
const ROOM_EXTENSION_WINDOW_MS = 60 * 1000;
const MAX_ROOM_EXTENSIONS = 2;
const INITIAL_GEM_BALANCE = 15;
const VIDEO_MATCHING_FACE_PURPOSE = "video_matching";
const VERIFIED_STATUSES = new Set([
  "verified",
  "approved",
  "passed",
  "success",
  "completed",
  "complete",
  "done",
]);

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function cleanString(value, maxLength = 128) {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, maxLength);
}

function normalizeGender(value) {
  const raw = cleanString(value, 16).toLowerCase();
  if (raw === "nam") return "male";
  if (raw === "nu" || raw === "nữ") return "female";
  if (raw === "male" || raw === "female") return raw;
  return "random";
}

function normalizeMatchingMode(value) {
  return cleanString(value, 16).toLowerCase() === "video" ? "video" : "chat";
}

function reputationScoreFrom(userData) {
  const rawValue = userData?.reputationScore;
  if (rawValue == null || rawValue === "") return 100;
  const value = Number(rawValue);
  return Number.isFinite(value) ? Math.trunc(value) : 100;
}

function minimumReputationForMode(matchingMode) {
  return normalizeMatchingMode(matchingMode) === "video"
    ? MIN_VIDEO_REPUTATION
    : MIN_TEMP_CHAT_REPUTATION;
}

function hasSufficientMatchingReputation(userData, matchingMode) {
  return reputationScoreFrom(userData) >=
    minimumReputationForMode(matchingMode);
}

function assertMatchingReputation(userData, matchingMode, participant) {
  if (hasSufficientMatchingReputation(userData, matchingMode)) return;

  throw new HttpsError(
    "failed-precondition",
    "Insufficient reputation for the selected matching mode.",
    {
      reason: "insufficient-reputation",
      matchingMode: normalizeMatchingMode(matchingMode),
      requiredReputation: minimumReputationForMode(matchingMode),
      currentReputation: reputationScoreFrom(userData),
      participant,
    }
  );
}

function gemBalanceFrom(userData) {
  const rawValue = userData?.gem;
  // Existing profiles created before the wallet field was introduced receive
  // the same opening balance as new profiles on their first server-side use.
  if (rawValue == null || rawValue === "") return INITIAL_GEM_BALANCE;
  const value = Number(rawValue);
  return Number.isInteger(value) && value >= 0 ? value : 0;
}

function assertSufficientVideoGem(userData, matchingMode, participant) {
  if (normalizeMatchingMode(matchingMode) !== "video") return;

  const currentGem = gemBalanceFrom(userData);
  if (currentGem >= VIDEO_MATCH_GEM_COST) return;

  throw new HttpsError(
    "resource-exhausted",
    "Insufficient gem balance for video matching.",
    {
      reason: "insufficient-gem",
      matchingMode: "video",
      requiredGem: VIDEO_MATCH_GEM_COST,
      currentGem,
      participant,
    }
  );
}

function videoMatchChargeId(roomId, uid) {
  return `video_match_${roomId}_${uid}`;
}

function videoMatchRefundId(roomId, uid) {
  return `video_match_refund_${roomId}_${uid}`;
}

function roomExtensionChargeId(roomId, extensionNumber) {
  return `room_extension_${roomId}_${extensionNumber}`;
}

function roomExtensionFailureReason(roomData, uid, nowMillis) {
  if (!roomData || roomData.status !== "active") return "room-not-active";
  if (!Array.isArray(roomData.participants) ||
      !roomData.participants.includes(uid)) {
    return "not-participant";
  }
  if (roomData.userALiked === true && roomData.userBLiked === true) {
    return "mutual-consent-complete";
  }

  const expiresAtMillis = roomData.expiresAt?.toMillis?.();
  if (!Number.isFinite(expiresAtMillis)) return "invalid-expiry";

  const remainingMs = expiresAtMillis - nowMillis;
  if (remainingMs <= 0) return "room-expired";
  if (remainingMs > ROOM_EXTENSION_WINDOW_MS) return "too-early";

  const extensionCount = Number(roomData.extensionCount || 0);
  if (!Number.isInteger(extensionCount) || extensionCount < 0 ||
      extensionCount >= MAX_ROOM_EXTENSIONS) {
    return "extension-limit-reached";
  }
  return null;
}

function faceProofFailureReason({
  userData,
  enrollmentData,
  proofData,
  uid,
  deviceId,
  nowMillis,
}) {
  if (userData?.isFaceVerified !== true) {
    return "face-enrollment-required";
  }
  if (!enrollmentData || enrollmentData.isActive === false) {
    return "face-enrollment-required";
  }
  if (!proofData) return "face-reauth-required";

  const expiresAt = proofData.expiresAt;
  const expiresAtMillis =
    expiresAt && typeof expiresAt.toMillis === "function"
      ? expiresAt.toMillis()
      : 0;
  const maxUses = Math.max(1, Number(proofData.maxUses) || 1);
  const useCount = Math.max(0, Number(proofData.useCount) || 0);
  if (
    proofData.uid !== uid ||
    proofData.status !== "valid" ||
    proofData.purpose !== VIDEO_MATCHING_FACE_PURPOSE ||
    expiresAtMillis <= nowMillis ||
    useCount >= maxUses
  ) {
    return "face-reauth-required";
  }
  if (!deviceId || proofData.deviceId !== deviceId) {
    return "face-proof-device-mismatch";
  }
  return null;
}

async function readVideoFaceAdmission(tx, {
  userSnap,
  uid,
  proofId,
  deviceId,
  matchingMode,
  participant,
  nowMillis,
}) {
  if (normalizeMatchingMode(matchingMode) !== "video") return null;

  const enrollmentRef = db.collection("faceEnrollments").doc(uid);
  const proofRef = proofId
    ? db.collection("faceReauthSessions").doc(proofId)
    : null;
  const refs = proofRef ? [enrollmentRef, proofRef] : [enrollmentRef];
  const snapshots = await tx.getAll(...refs);
  const enrollmentSnap = snapshots[0];
  const proofSnap = proofRef ? snapshots[1] : null;
  const reason = faceProofFailureReason({
    userData: userSnap.data() || {},
    enrollmentData: enrollmentSnap.exists ? enrollmentSnap.data() : null,
    proofData: proofSnap?.exists ? proofSnap.data() : null,
    uid,
    deviceId,
    nowMillis,
  });
  if (reason) {
    throw new HttpsError(
      "failed-precondition",
      "Fresh face verification is required for video matching.",
      {
        reason,
        matchingMode: "video",
        participant,
      }
    );
  }

  const proofData = proofSnap.data() || {};
  return {
    proofRef,
    useCount: Math.max(0, Number(proofData.useCount) || 0),
  };
}

function isActiveTempRoomForUser(room, uid) {
  const participants = Array.isArray(room?.participants) ? room.participants : [];
  return room?.status === "active" && participants.includes(uid);
}

function isMutualMatch(seeker, candidate) {
  const accepts = (target, gender) => target === "random" || target === gender;
  return normalizeMatchingMode(seeker.matchingMode) ===
      normalizeMatchingMode(candidate.matchingMode) &&
    accepts(seeker.targetGender, candidate.gender) &&
    accepts(candidate.targetGender, seeker.gender);
}

function normalizeStatus(value) {
  return cleanString(value, 64).toLowerCase().replace(/[\s_-]+/g, "");
}

function isTruthy(value) {
  if (value === true || value === 1) return true;
  if (typeof value !== "string") return false;
  return value.trim().toLowerCase() === "true" || value.trim() === "1";
}

function hasVerifiedStatus(data, keys) {
  return keys.some((key) => VERIFIED_STATUSES.has(normalizeStatus(data?.[key])));
}

function isVerifiedAccount(data) {
  const flagKeys = [
    "isFaceVerified",
    "isVerified",
    "verified",
    "isAccountVerified",
    "accountVerified",
    "identityVerified",
    "isIdentityVerified",
    "kycVerified",
    "isKycVerified",
  ];
  if (flagKeys.some((key) => isTruthy(data?.[key]))) return true;

  if (hasVerifiedStatus(data, [
    "verificationStatus",
    "accountVerificationStatus",
    "identityVerificationStatus",
    "faceVerificationStatus",
    "accountStatus",
  ])) return true;

  if ([
    "faceVerifiedAt",
    "verifiedAt",
    "accountVerifiedAt",
    "identityVerifiedAt",
  ].some((key) => data?.[key] != null)) return true;

  const nested = data?.verification;
  if (!nested || typeof nested !== "object" || Array.isArray(nested)) return false;
  return [
    "isVerified",
    "verified",
    "isFaceVerified",
    "accountVerified",
    "identityVerified",
  ].some((key) => isTruthy(nested[key])) ||
    hasVerifiedStatus(nested, ["status", "state"]) ||
    ["verifiedAt", "faceVerifiedAt", "accountVerifiedAt"]
      .some((key) => nested[key] != null);
}

function bangkokDateKey(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function quotaPatch(userData, now, participant = null) {
  if (isVerifiedAccount(userData)) return {};
  const today = bangkokDateKey(now);
  const used = userData?.dailyMatchingDate === today
    ? Math.max(0, Number(userData?.dailyMatchingCount) || 0)
    : 0;
  if (used >= DAILY_MATCH_LIMIT) {
    throw new HttpsError(
      "resource-exhausted",
      "Daily matching limit reached.",
      {
        reason: "daily-matching-limit",
        participant,
      }
    );
  }
  return {
    dailyMatchingCount: used + 1,
    dailyMatchingDate: today,
  };
}

async function hasBlockInTransaction(tx, uidA, uidB) {
  const refs = [
    db.collection("users").doc(uidA).collection("blockedUsers").doc(uidB),
    db.collection("users").doc(uidA).collection("blockedBy").doc(uidB),
    db.collection("users").doc(uidB).collection("blockedUsers").doc(uidA),
    db.collection("users").doc(uidB).collection("blockedBy").doc(uidA),
  ];
  const snapshots = await tx.getAll(...refs);
  return snapshots.some((snapshot) => snapshot.exists);
}

async function enqueueSeeker({
  uid,
  sessionId,
  targetGender,
  avatar,
  matchingMode,
  faceProofId,
  deviceId,
}) {
  const userRef = db.collection("users").doc(uid);
  const queueRef = db.collection(QUEUE_COLLECTION).doc(uid);
  const now = new Date();

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }
    const activeRoomId = cleanString(userSnap.get("activeTempRoomId"));
    let shouldClearStaleRoom = false;
    if (activeRoomId) {
      const activeRoom = await tx.get(db.collection("tempChats").doc(activeRoomId));
      if (activeRoom.exists && isActiveTempRoomForUser(activeRoom.data(), uid)) {
        if (normalizeMatchingMode(activeRoom.get("matchingMode")) !== matchingMode) {
          throw new HttpsError(
            "failed-precondition",
            "Another temporary session is already active."
          );
        }
        return activeRoomId;
      }
      // Recover from a stale lock left by an interrupted cleanup trigger.
      shouldClearStaleRoom = true;
    }
    assertMatchingReputation(userSnap.data() || {}, matchingMode, "seeker");
    assertSufficientVideoGem(userSnap.data() || {}, matchingMode, "seeker");
    // Validate quota now, but consume it only after a room is created.
    quotaPatch(userSnap.data() || {}, now);
    await readVideoFaceAdmission(tx, {
      userSnap,
      uid,
      proofId: faceProofId,
      deviceId,
      matchingMode,
      participant: "seeker",
      nowMillis: now.getTime(),
    });

    const gender = normalizeGender(userSnap.get("gender"));
    if (shouldClearStaleRoom) {
      tx.set(userRef, { activeTempRoomId: null }, { merge: true });
    }
    tx.set(queueRef, {
      uid,
      sessionId,
      gender,
      targetGender,
      matchingMode,
      ...(matchingMode === "video"
        ? { faceProofId, deviceId }
        : {}),
      anonymousAvatar: avatar,
      status: "waiting",
      createdAt: admin.firestore.Timestamp.fromDate(now),
      expiresAt: admin.firestore.Timestamp.fromMillis(now.getTime() + QUEUE_TTL_MS),
      roomId: null,
    });
    tx.set(userRef, {
      isMatching: true,
      activeMatchingSessionId: sessionId,
    }, { merge: true });
    return null;
  });
}

async function tryCreateMatch({ uid, sessionId, matchingMode }) {
  const seekerRef = db.collection(QUEUE_COLLECTION).doc(uid);
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - QUEUE_TTL_MS);
  const candidates = await db.collection(QUEUE_COLLECTION)
    .where("status", "==", "waiting")
    .where("matchingMode", "==", matchingMode)
    .where("createdAt", ">=", cutoff)
    .orderBy("createdAt", "asc")
    .limit(MATCH_SCAN_LIMIT)
    .get();

  for (const candidateDoc of candidates.docs) {
    if (candidateDoc.id === uid) continue;
    const candidateUid = candidateDoc.id;
    const candidateRef = candidateDoc.ref;
    const roomRef = db.collection("tempChats").doc();
    const callRef = db.collection("callSessions").doc(`video_${roomRef.id}`);

    try {
      const roomId = await db.runTransaction(async (tx) => {
        const [seekerSnap, candidateSnap] = await tx.getAll(
          seekerRef,
          candidateRef
        );
        if (!seekerSnap.exists || !candidateSnap.exists) return null;

        const seeker = seekerSnap.data() || {};
        const candidate = candidateSnap.data() || {};
        if (seeker.status !== "waiting" || seeker.sessionId !== sessionId) return null;
        if (candidate.status !== "waiting") return null;
        if (!isMutualMatch(seeker, candidate)) return null;

        const [seekerUser, candidateUser] = await tx.getAll(
          db.collection("users").doc(uid),
          db.collection("users").doc(candidateUid)
        );
        if (!seekerUser.exists || !candidateUser.exists) return null;
        assertMatchingReputation(
          seekerUser.data() || {},
          matchingMode,
          "seeker"
        );
        assertMatchingReputation(
          candidateUser.data() || {},
          matchingMode,
          "candidate"
        );
        assertSufficientVideoGem(
          seekerUser.data() || {},
          matchingMode,
          "seeker"
        );
        assertSufficientVideoGem(
          candidateUser.data() || {},
          matchingMode,
          "candidate"
        );
        const seekerFaceAdmission = await readVideoFaceAdmission(tx, {
          userSnap: seekerUser,
          uid,
          proofId: cleanString(seeker.faceProofId, 256),
          deviceId: cleanString(seeker.deviceId, 128),
          matchingMode,
          participant: "seeker",
          nowMillis: Date.now(),
        });
        const candidateFaceAdmission = await readVideoFaceAdmission(tx, {
          userSnap: candidateUser,
          uid: candidateUid,
          proofId: cleanString(candidate.faceProofId, 256),
          deviceId: cleanString(candidate.deviceId, 128),
          matchingMode,
          participant: "candidate",
          nowMillis: Date.now(),
        });
        if (await hasBlockInTransaction(tx, uid, candidateUid)) return null;

        const now = new Date();
        const roomMatchingMode = normalizeMatchingMode(seeker.matchingMode);
        const durationMs = roomMatchingMode === "video"
          ? VIDEO_CHAT_DURATION_MS
          : TEMP_CHAT_DURATION_MS;
        const seekerQuota = quotaPatch(
          seekerUser.data() || {},
          now,
          "seeker"
        );
        const candidateQuota = quotaPatch(
          candidateUser.data() || {},
          now,
          "candidate"
        );
        const seekerGemBefore = gemBalanceFrom(seekerUser.data() || {});
        const candidateGemBefore = gemBalanceFrom(candidateUser.data() || {});
        const createdAt = admin.firestore.Timestamp.fromDate(now);
        const expiresAt = admin.firestore.Timestamp.fromMillis(
          now.getTime() + durationMs
        );
        const cameraUnlockAt = admin.firestore.Timestamp.fromMillis(
          now.getTime() + VIDEO_CAMERA_LOCK_MS
        );

        tx.create(roomRef, {
          roomId: roomRef.id,
          userA: uid,
          userB: candidateUid,
          participants: [uid, candidateUid],
          createdAt,
          expiresAt,
          durationSeconds: durationMs / 1000,
          matchingMode: roomMatchingMode,
          sessionA: seeker.sessionId,
          sessionB: candidate.sessionId,
          sessionIds: [seeker.sessionId, candidate.sessionId],
          status: "active",
          extensionCount: 0,
          userALiked: null,
          userBLiked: null,
          permanentRoomId: null,
          conversionStatus: "idle",
          typing: { userA: false, userB: false },
          anonymousAvatars: {
            [uid]: seeker.anonymousAvatar,
            [candidateUid]: candidate.anonymousAvatar,
          },
          ...(roomMatchingMode === "video" ? {
            cameraUnlockAt,
            callSessionId: callRef.id,
            videoCameraStates: {
              [uid]: false,
              [candidateUid]: false,
            },
            videoMutedStates: {
              [uid]: false,
              [candidateUid]: false,
            },
          } : {}),
        });
        if (roomMatchingMode === "video") {
          // The session starts as active so the normal incoming-call listener,
          // which only watches "ringing", never exposes either anonymous user.
          tx.create(callRef, {
            callId: callRef.id,
            roomChatId: roomRef.id,
            callerId: uid,
            receiverId: candidateUid,
            participants: [uid, candidateUid],
            type: "video",
            status: "active",
            offer: null,
            answer: null,
            createdAt,
            updatedAt: createdAt,
          });
          tx.update(seekerFaceAdmission.proofRef, {
            useCount: seekerFaceAdmission.useCount + 1,
            lastUsedAt: createdAt,
          });
          tx.update(candidateFaceAdmission.proofRef, {
            useCount: candidateFaceAdmission.useCount + 1,
            lastUsedAt: createdAt,
          });
        }
        tx.update(seekerRef, {
          status: "matched",
          roomId: roomRef.id,
          matchedAt: createdAt,
        });
        tx.update(candidateRef, {
          status: "matched",
          roomId: roomRef.id,
          matchedAt: createdAt,
        });
        tx.set(seekerUser.ref, {
          ...seekerQuota,
          ...(roomMatchingMode === "video"
            ? { gem: seekerGemBefore - VIDEO_MATCH_GEM_COST }
            : {}),
          isMatching: false,
          activeMatchingSessionId: null,
          activeTempRoomId: roomRef.id,
        }, { merge: true });
        tx.set(candidateUser.ref, {
          ...candidateQuota,
          ...(roomMatchingMode === "video"
            ? { gem: candidateGemBefore - VIDEO_MATCH_GEM_COST }
            : {}),
          isMatching: false,
          activeMatchingSessionId: null,
          activeTempRoomId: roomRef.id,
        }, { merge: true });
        if (roomMatchingMode === "video") {
          for (const charge of [
            {
              uid,
              sessionId: seeker.sessionId,
              balanceBefore: seekerGemBefore,
            },
            {
              uid: candidateUid,
              sessionId: candidate.sessionId,
              balanceBefore: candidateGemBefore,
            },
          ]) {
            tx.create(
              db.collection("gemTransactions")
                .doc(videoMatchChargeId(roomRef.id, charge.uid)),
              {
                uid: charge.uid,
                roomId: roomRef.id,
                matchingSessionId: charge.sessionId,
                amount: -VIDEO_MATCH_GEM_COST,
                reason: "video_matching",
                status: "charged",
                balanceBefore: charge.balanceBefore,
                balanceAfter: charge.balanceBefore - VIDEO_MATCH_GEM_COST,
                createdAt,
                refundedAt: null,
                refundReason: null,
              }
            );
          }
        }
        return roomRef.id;
      });
      if (roomId) return roomId;
    } catch (error) {
      if (
        error instanceof HttpsError &&
        error.code === "failed-precondition" &&
        [
          "insufficient-reputation",
          "face-enrollment-required",
          "face-reauth-required",
          "face-proof-device-mismatch",
        ].includes(error.details?.reason) &&
        error.details?.participant === "candidate"
      ) {
        // Reputation can change while a user waits in the queue. Remove an
        // ineligible candidate and continue scanning without blocking others.
        const batch = db.batch();
        batch.set(candidateRef, { status: "expired" }, { merge: true });
        batch.set(db.collection("users").doc(candidateUid), {
          isMatching: false,
          activeMatchingSessionId: null,
        }, { merge: true });
        await batch.commit();
        continue;
      }
      if (
        error instanceof HttpsError &&
        error.code === "resource-exhausted" &&
        error.details?.participant === "candidate"
      ) {
        // A stale candidate with no quota/gem must not block the rest of the
        // queue. Seeker errors are returned to their own client.
        const batch = db.batch();
        batch.set(candidateRef, { status: "expired" }, { merge: true });
        batch.set(db.collection("users").doc(candidateUid), {
          isMatching: false,
          activeMatchingSessionId: null,
        }, { merge: true });
        await batch.commit();
        continue;
      }
      throw error;
    }
  }
  return null;
}

async function refundVideoMatch(roomId, reason) {
  const roomRef = db.collection("tempChats").doc(roomId);

  return db.runTransaction(async (tx) => {
    const roomSnap = await tx.get(roomRef);
    if (!roomSnap.exists) return false;

    const room = roomSnap.data() || {};
    const participants = Array.isArray(room.participants)
      ? room.participants
      : [];
    if (
      room.matchingMode !== "video" ||
      room.status !== "ended" ||
      room.endedBy !== "system" ||
      !["system_error", "matching_setup_failed"].includes(room.endedReason) ||
      participants.length !== 2
    ) {
      return false;
    }

    const chargeRefs = participants.map((participant) =>
      db.collection("gemTransactions")
        .doc(videoMatchChargeId(roomId, participant))
    );
    const userRefs = participants.map((participant) =>
      db.collection("users").doc(participant)
    );
    const snapshots = await tx.getAll(...chargeRefs, ...userRefs);
    const chargeSnapshots = snapshots.slice(0, participants.length);
    const userSnapshots = snapshots.slice(participants.length);
    const canRefundEveryone = participants.every((_, index) =>
      chargeSnapshots[index].exists &&
      chargeSnapshots[index].get("status") === "charged" &&
      userSnapshots[index].exists
    );
    if (!canRefundEveryone) return false;

    const refundedAt = admin.firestore.Timestamp.now();

    participants.forEach((participant, index) => {
      const userSnap = userSnapshots[index];
      const balanceBeforeRefund = gemBalanceFrom(userSnap.data() || {});
      const balanceAfterRefund = balanceBeforeRefund + VIDEO_MATCH_GEM_COST;
      tx.set(userRefs[index], { gem: balanceAfterRefund }, { merge: true });
      tx.update(chargeRefs[index], {
        status: "refunded",
        refundedAt,
        refundReason: reason,
      });
      tx.create(
        db.collection("gemTransactions")
          .doc(videoMatchRefundId(roomId, participant)),
        {
          uid: participant,
          roomId,
          amount: VIDEO_MATCH_GEM_COST,
          reason: "video_matching_refund",
          status: "completed",
          balanceBefore: balanceBeforeRefund,
          balanceAfter: balanceAfterRefund,
          relatedTransactionId: chargeRefs[index].id,
          refundReason: reason,
          createdAt: refundedAt,
        }
      );
    });
    return true;
  });
}

const refundFailedVideoMatch = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    if (
      before.status === "ended" ||
      after.status !== "ended" ||
      after.endedBy !== "system" ||
      !["system_error", "matching_setup_failed"].includes(after.endedReason)
    ) {
      return;
    }
    await refundVideoMatch(event.params.roomId, after.endedReason);
  }
);

const startTempChatMatching = onCall(async (request) => {
  const uid = requireUid(request);
  const sessionId = cleanString(request.data?.sessionId);
  const targetGender = normalizeGender(request.data?.targetGender);
  const matchingMode = normalizeMatchingMode(request.data?.matchingMode);
  const avatar = cleanString(request.data?.anonymousAvatar, 32);
  const faceProofId = cleanString(request.data?.faceProofId, 256);
  const deviceId = cleanString(request.data?.deviceId, 128);
  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  if (!/^avt_\d{2}$/.test(avatar)) {
    throw new HttpsError("invalid-argument", "Anonymous avatar is invalid.");
  }

  const activeRoomId = await enqueueSeeker({
    uid,
    sessionId,
    targetGender,
    avatar,
    matchingMode,
    faceProofId,
    deviceId,
  });
  if (activeRoomId) {
    return { status: "matched", roomId: activeRoomId, resumed: true };
  }
  const roomId = await tryCreateMatch({ uid, sessionId, matchingMode });
  return { status: roomId ? "matched" : "waiting", roomId };
});

const cancelTempChatMatching = onCall(async (request) => {
  const uid = requireUid(request);
  const sessionId = cleanString(request.data?.sessionId);
  const queueRef = db.collection(QUEUE_COLLECTION).doc(uid);
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const queueSnap = await tx.get(queueRef);
    if (queueSnap.exists) {
      const queue = queueSnap.data() || {};
      if (queue.status === "waiting" && (!sessionId || queue.sessionId === sessionId)) {
        tx.update(queueRef, {
          status: "cancelled",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    tx.set(userRef, {
      isMatching: false,
      activeMatchingSessionId: null,
    }, { merge: true });
  });
  return { cancelled: true };
});

const extendTempChatRoom = onCall(async (request) => {
  const uid = requireUid(request);
  const roomId = cleanString(request.data?.roomId, 128);
  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId is required.");
  }

  const roomRef = db.collection("tempChats").doc(roomId);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [roomSnap, userSnap] = await tx.getAll(roomRef, userRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Temp room not found.");
    }
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const roomData = roomSnap.data() || {};
    const nowMillis = Date.now();
    const failureReason = roomExtensionFailureReason(
      roomData,
      uid,
      nowMillis
    );
    if (failureReason) {
      const code = failureReason === "not-participant"
        ? "permission-denied"
        : "failed-precondition";
      throw new HttpsError(code, "Room cannot be extended.", {
        reason: failureReason,
        extensionCount: Number(roomData.extensionCount || 0),
        maxExtensions: MAX_ROOM_EXTENSIONS,
      });
    }

    const userData = userSnap.data() || {};
    const balanceBefore = gemBalanceFrom(userData);
    if (balanceBefore < ROOM_EXTENSION_GEM_COST) {
      throw new HttpsError(
        "resource-exhausted",
        "Insufficient gem balance for room extension.",
        {
          reason: "insufficient-gem",
          requiredGem: ROOM_EXTENSION_GEM_COST,
          currentGem: balanceBefore,
        }
      );
    }

    const currentCount = Number(roomData.extensionCount || 0);
    const extensionNumber = currentCount + 1;
    const previousExpiresAtMillis = roomData.expiresAt.toMillis();
    const nextExpiresAt = admin.firestore.Timestamp.fromMillis(
      previousExpiresAtMillis + ROOM_EXTENSION_DURATION_MS
    );
    const extendedAt = admin.firestore.Timestamp.fromMillis(nowMillis);
    const transactionRef = db.collection("gemTransactions")
      .doc(roomExtensionChargeId(roomId, extensionNumber));

    tx.update(roomRef, {
      expiresAt: nextExpiresAt,
      extensionCount: extensionNumber,
      lastExtendedAt: extendedAt,
      lastExtendedBy: uid,
    });
    tx.update(userRef, {
      gem: balanceBefore - ROOM_EXTENSION_GEM_COST,
    });
    tx.create(transactionRef, {
      uid,
      roomId,
      matchingMode: normalizeMatchingMode(roomData.matchingMode),
      extensionNumber,
      amount: -ROOM_EXTENSION_GEM_COST,
      reason: "temp_room_extension",
      status: "charged",
      balanceBefore,
      balanceAfter: balanceBefore - ROOM_EXTENSION_GEM_COST,
      createdAt: extendedAt,
    });

    return {
      success: true,
      extensionCount: extensionNumber,
      maxExtensions: MAX_ROOM_EXTENSIONS,
      addedSeconds: ROOM_EXTENSION_DURATION_MS / 1000,
      expiresAt: nextExpiresAt.toDate().toISOString(),
      gemBalance: balanceBefore - ROOM_EXTENSION_GEM_COST,
    };
  });
});

const revokeVideoMatchingFaceProof = onCall(async (request) => {
  const uid = requireUid(request);
  const proofId = cleanString(request.data?.faceProofId, 256);
  const deviceId = cleanString(request.data?.deviceId, 128);
  if (!proofId || !deviceId) {
    throw new HttpsError(
      "invalid-argument",
      "faceProofId and deviceId are required."
    );
  }
  const proofRef = db.collection("faceReauthSessions").doc(proofId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(proofRef);
    if (!snapshot.exists) return;
    const data = snapshot.data() || {};
    if (
      data.uid !== uid ||
      data.deviceId !== deviceId ||
      data.purpose !== VIDEO_MATCHING_FACE_PURPOSE
    ) {
      throw new HttpsError("permission-denied", "Face proof is not owned.");
    }
    if (data.status !== "valid") return;
    tx.update(proofRef, {
      status: "revoked",
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      revokedReason: "app_background_timeout",
    });
  });
  return { revoked: true };
});

async function convertTempRoom(tempRoomId, requesterUid = null) {
  const tempRef = db.collection("tempChats").doc(tempRoomId);
  const permanentRef = db.collection("chatRooms").doc(`temp_${tempRoomId}`);

  return db.runTransaction(async (tx) => {
    const tempSnap = await tx.get(tempRef);
    if (!tempSnap.exists) throw new HttpsError("not-found", "Temp room not found.");
    const room = tempSnap.data() || {};
    const participants = Array.isArray(room.participants) ? room.participants : [];
    if (requesterUid && !participants.includes(requesterUid)) {
      throw new HttpsError("permission-denied", "User is not a room participant.");
    }
    if (room.status === "converted" && room.permanentRoomId) {
      return { roomId: room.permanentRoomId };
    }
    if (room.status !== "active" || room.userALiked !== true || room.userBLiked !== true) {
      throw new HttpsError("failed-precondition", "Mutual consent is required.");
    }
    if (participants.length !== 2 || await hasBlockInTransaction(
      tx,
      participants[0],
      participants[1]
    )) {
      throw new HttpsError("failed-precondition", "Conversion is not allowed.");
    }

    tx.set(permanentRef, {
      participants,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      fromTempRoom: tempRoomId,
      e2ee: true,
      lastMessage: "Bắt đầu trò chuyện",
      lastMessageType: "system",
      lastSenderId: null,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      unread: Object.fromEntries(participants.map((participant) => [participant, 0])),
      migrated: false,
    }, { merge: false });
    tx.update(tempRef, {
      status: "converted",
      permanentRoomId: permanentRef.id,
      conversionStatus: "ready",
      convertedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const callSessionId = cleanString(room.callSessionId);
    if (callSessionId) {
      tx.set(db.collection("callSessions").doc(callSessionId), {
        status: "ended",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    for (const participant of participants) {
      tx.set(db.collection("users").doc(participant), {
        activeTempRoomId: null,
      }, { merge: true });
    }
    return { roomId: permanentRef.id };
  });
}

const convertTempChat = onCall(async (request) => {
  const uid = requireUid(request);
  const tempRoomId = cleanString(request.data?.roomId);
  if (!tempRoomId) {
    throw new HttpsError("invalid-argument", "roomId is required.");
  }
  return convertTempRoom(tempRoomId, uid);
});

const convertMutualTempChat = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const wasMutual = before.userALiked === true && before.userBLiked === true;
    const isMutual = after.userALiked === true && after.userBLiked === true;
    if (wasMutual || !isMutual || after.status !== "active") return;
    await convertTempRoom(event.params.roomId);
  }
);

const releaseEndedTempChatParticipants = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    if (before.status !== "active" || after.status === "active") return;
    const participants = Array.isArray(after.participants) ? after.participants : [];
    const roomId = event.params.roomId;

    const callSessionId = cleanString(after.callSessionId);
    if (callSessionId) {
      await db.collection("callSessions").doc(callSessionId).set({
        status: "ended",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await Promise.all(participants.map(async (participant) => {
      const userRef = db.collection("users").doc(participant);
      await db.runTransaction(async (tx) => {
        const user = await tx.get(userRef);
        if (!user.exists || user.get("activeTempRoomId") !== roomId) return;
        tx.set(userRef, { activeTempRoomId: null }, { merge: true });
      });
    }));
  }
);

const expireTempChatSessions = onSchedule(
  { schedule: "every 1 minutes", timeZone: "Asia/Bangkok" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const rooms = await db.collection("tempChats")
      .where("status", "==", "active")
      .where("expiresAt", "<=", now)
      .limit(200)
      .get();
    if (rooms.empty) return;

    const batch = db.batch();
    for (const room of rooms.docs) {
      batch.update(room.ref, {
        status: "ended",
        endedReason: "timeout",
        endedBy: "system",
        endedAt: now,
      });
    }
    await batch.commit();
  }
);

const cleanupExpiredMatchingSessions = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Bangkok" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const sessions = await db.collection(QUEUE_COLLECTION)
      .where("status", "==", "waiting")
      .where("expiresAt", "<=", now)
      .limit(200)
      .get();

    await Promise.all(sessions.docs.map(async (session) => {
      const data = session.data() || {};
      const userRef = db.collection("users").doc(session.id);
      await db.runTransaction(async (tx) => {
        const [latestSession, user] = await tx.getAll(session.ref, userRef);
        if (!latestSession.exists || latestSession.get("status") !== "waiting") return;
        tx.update(session.ref, {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (user.exists && user.get("activeMatchingSessionId") === data.sessionId) {
          tx.set(userRef, {
            isMatching: false,
            activeMatchingSessionId: null,
          }, { merge: true });
        }
      });
    }));
  }
);

const cleanupExpiredTempChatPresence = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Bangkok" },
  async () => {
    const expired = await db.collectionGroup("presence")
      .where("expiresAt", "<=", admin.firestore.Timestamp.now())
      .limit(400)
      .get();
    if (expired.empty) return;

    const batch = db.batch();
    for (const presence of expired.docs) {
      // This collection group is currently reserved for temp-chat presence.
      if (presence.ref.parent.parent?.parent.id !== "tempChats") continue;
      batch.delete(presence.ref);
    }
    await batch.commit();
  }
);

module.exports = {
  startTempChatMatching,
  cancelTempChatMatching,
  extendTempChatRoom,
  revokeVideoMatchingFaceProof,
  convertTempChat,
  expireTempChatSessions,
  cleanupExpiredMatchingSessions,
  cleanupExpiredTempChatPresence,
  convertMutualTempChat,
  releaseEndedTempChatParticipants,
  refundFailedVideoMatch,
  __test: {
    normalizeGender,
    normalizeMatchingMode,
    isActiveTempRoomForUser,
    isMutualMatch,
    reputationScoreFrom,
    minimumReputationForMode,
    hasSufficientMatchingReputation,
    assertMatchingReputation,
    gemBalanceFrom,
    assertSufficientVideoGem,
    videoMatchChargeId,
    videoMatchRefundId,
    roomExtensionChargeId,
    roomExtensionFailureReason,
    faceProofFailureReason,
    isVerifiedAccount,
    bangkokDateKey,
    quotaPatch,
  },
};
