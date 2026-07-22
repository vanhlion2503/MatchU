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

function quotaPatch(userData, now) {
  if (isVerifiedAccount(userData)) return {};
  const today = bangkokDateKey(now);
  const used = userData?.dailyMatchingDate === today
    ? Math.max(0, Number(userData?.dailyMatchingCount) || 0)
    : 0;
  if (used >= DAILY_MATCH_LIMIT) {
    throw new HttpsError("resource-exhausted", "Daily matching limit reached.");
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
      tx.set(userRef, { activeTempRoomId: null }, { merge: true });
    }
    // Validate quota now, but consume it only after a room is created.
    quotaPatch(userSnap.data() || {}, now);

    const gender = normalizeGender(userSnap.get("gender"));
    tx.set(queueRef, {
      uid,
      sessionId,
      gender,
      targetGender,
      matchingMode,
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
        if (await hasBlockInTransaction(tx, uid, candidateUid)) return null;

        const now = new Date();
        const matchingMode = normalizeMatchingMode(seeker.matchingMode);
        const durationMs = matchingMode === "video"
          ? VIDEO_CHAT_DURATION_MS
          : TEMP_CHAT_DURATION_MS;
        const seekerQuota = quotaPatch(seekerUser.data() || {}, now);
        const candidateQuota = quotaPatch(candidateUser.data() || {}, now);
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
          matchingMode,
          sessionA: seeker.sessionId,
          sessionB: candidate.sessionId,
          sessionIds: [seeker.sessionId, candidate.sessionId],
          status: "active",
          userALiked: null,
          userBLiked: null,
          permanentRoomId: null,
          conversionStatus: "idle",
          typing: { userA: false, userB: false },
          anonymousAvatars: {
            [uid]: seeker.anonymousAvatar,
            [candidateUid]: candidate.anonymousAvatar,
          },
          ...(matchingMode === "video" ? {
            cameraUnlockAt,
            callSessionId: callRef.id,
            videoCameraStates: {
              [uid]: false,
              [candidateUid]: false,
            },
          } : {}),
        });
        if (matchingMode === "video") {
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
          isMatching: false,
          activeMatchingSessionId: null,
          activeTempRoomId: roomRef.id,
        }, { merge: true });
        tx.set(candidateUser.ref, {
          ...candidateQuota,
          isMatching: false,
          activeMatchingSessionId: null,
          activeTempRoomId: roomRef.id,
        }, { merge: true });
        return roomRef.id;
      });
      if (roomId) return roomId;
    } catch (error) {
      if (error instanceof HttpsError && error.code === "resource-exhausted") {
        // A stale candidate with no quota must not block the rest of the queue.
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

const startTempChatMatching = onCall(async (request) => {
  const uid = requireUid(request);
  const sessionId = cleanString(request.data?.sessionId);
  const targetGender = normalizeGender(request.data?.targetGender);
  const matchingMode = normalizeMatchingMode(request.data?.matchingMode);
  const avatar = cleanString(request.data?.anonymousAvatar, 32);
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
  convertTempChat,
  expireTempChatSessions,
  cleanupExpiredMatchingSessions,
  cleanupExpiredTempChatPresence,
  convertMutualTempChat,
  releaseEndedTempChatParticipants,
  __test: {
    normalizeGender,
    normalizeMatchingMode,
    isActiveTempRoomForUser,
    isMutualMatch,
    isVerifiedAccount,
    bangkokDateKey,
    quotaPatch,
  },
};
