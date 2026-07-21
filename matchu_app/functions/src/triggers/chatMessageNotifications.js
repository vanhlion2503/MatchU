const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");

const REGION = "asia-southeast1";
const NOTIFICATION_QUEUE_COLLECTION = "chatNotificationQueues";
const SENDER_RATE_LIMIT_COLLECTION = "chatNotificationSenderRateLimits";

const INITIAL_NOTIFICATION_DELAY_MS = 650;
const MIN_GAP_BETWEEN_NOTIFICATIONS_MS = 1800;
const RATE_LIMIT_WINDOW_MS = 2000;
const RATE_LIMIT_MAX_MESSAGES = 5;
const MAX_NOTIFICATION_PREVIEW_LENGTH = 160;
const DISPATCH_LEASE_MS = 60 * 1000;
const QUEUE_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
const RATE_LIMIT_RETENTION_MS = 24 * 60 * 60 * 1000;
const MAINTENANCE_BATCH_SIZE = 200;

const DELIVERY_MODE_FOREGROUND = "foreground_data";
const DELIVERY_MODE_PUSH = "push";

const queueChatMessageNotification = onDocumentCreated(
  {
    document: "chatRooms/{roomId}/messages/{messageId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data() || {};
    if (messageData.type === "system") return;

    const senderUid = cleanString(messageData.senderId);
    if (!senderUid) return;

    const roomId = event.params.roomId;
    const roomSnap = await db.collection("chatRooms").doc(roomId).get();
    if (!roomSnap.exists) return;

    const roomData = roomSnap.data() || {};
    const participants = Array.isArray(roomData.participants)
      ? roomData.participants.filter((value) => typeof value === "string")
      : [];

    const recipientUid = participants.find((uid) => uid !== senderUid);
    if (!recipientUid || recipientUid === senderUid) return;

    const senderProfileSnap = await db.collection("users").doc(senderUid).get();
    const senderProfile = senderProfileSnap.data() || {};
    const senderName =
      cleanString(senderProfile.fullname) ||
      cleanString(senderProfile.nickname) ||
      "MatchU";

    const messageType = messageData.type === "image"
      ? "image"
      : messageData.type === "post_share"
        ? "post_share"
        : "text";
    const messagePreview = extractMessagePreview(messageData, messageType);
    const nowMs = Date.now();
    const rateLimitDelayMs = await computeSenderDelayMs(senderUid, nowMs);
    const queueRef = db
      .collection(NOTIFICATION_QUEUE_COLLECTION)
      .doc(`${roomId}_${recipientUid}`);

    await db.runTransaction(async (transaction) => {
      const queueSnap = await transaction.get(queueRef);
      const current = queueSnap.exists ? queueSnap.data() || {} : {};

      const hasPendingNotification = current.status === "pending";
      const pendingCount =
        hasPendingNotification ? (toInt(current.pendingCount) || 0) + 1 : 1;
      const existingScheduledAtMs = timestampToMillis(current.scheduledAt);
      const lastSentAtMs = timestampToMillis(current.lastSentAt);
      const minGapDelayMs = Math.max(
        0,
        lastSentAtMs + MIN_GAP_BETWEEN_NOTIFICATIONS_MS - nowMs
      );
      const scheduledAtMs = hasPendingNotification && existingScheduledAtMs > 0
        ? Math.max(
            existingScheduledAtMs,
            nowMs + Math.max(rateLimitDelayMs, minGapDelayMs)
          )
        : nowMs +
          Math.max(
            INITIAL_NOTIFICATION_DELAY_MS,
            rateLimitDelayMs,
            minGapDelayMs
          );

      transaction.set(
        queueRef,
        {
          roomId,
          recipientUid,
          senderUid,
          senderName,
          lastMessageId: event.params.messageId,
          lastMessageType: messageType,
          lastMessagePreview: messagePreview,
          lastMessageAt:
            messageData.createdAt || admin.firestore.Timestamp.fromMillis(nowMs),
          pendingCount,
          scheduledAt: admin.firestore.Timestamp.fromMillis(scheduledAtMs),
          status: "pending",
          version: (toInt(current.version) || 0) + 1,
          createdAt: current.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(
            nowMs + QUEUE_RETENTION_MS
          ),
          lastSentAt: current.lastSentAt || null,
        },
        { merge: true }
      );
    });

    if (cleanString(messageData.notificationPreview)) {
      await snapshot.ref.set(
        {
          notificationPreview: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );
    }
  }
);

const dispatchQueuedChatNotification = onDocumentWritten(
  {
    document: `${NOTIFICATION_QUEUE_COLLECTION}/{queueId}`,
    region: REGION,
  },
  async (event) => {
    const after = event.data.after;
    if (!after || !after.exists) return;

    const data = after.data() || {};
    if (data.status !== "pending") return;

    const version = toInt(data.version) || 0;
    await waitUntil(data.scheduledAt);

    let currentSnap = await after.ref.get();
    if (!currentSnap.exists) return;

    let currentData = currentSnap.data() || {};
    if (currentData.status !== "pending") return;
    if ((toInt(currentData.version) || 0) !== version) return;

    const remainingDelayMs = timestampToMillis(currentData.scheduledAt) - Date.now();
    if (remainingDelayMs > 0) {
      await sleep(remainingDelayMs);

      currentSnap = await after.ref.get();
      if (!currentSnap.exists) return;

      currentData = currentSnap.data() || {};
      if (currentData.status !== "pending") return;
      if ((toInt(currentData.version) || 0) !== version) return;
    }

    const claim = await claimNotification(currentSnap.ref, version);
    if (!claim) return;

    await dispatchNotification(currentSnap.ref, claim);
  }
);

async function claimNotification(queueRef, expectedVersion) {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(queueRef);
    if (!snap.exists) return null;

    const data = snap.data() || {};
    if (data.status !== "pending") return null;
    if ((toInt(data.version) || 0) !== expectedVersion) return null;
    if (timestampToMillis(data.scheduledAt) > Date.now()) return null;

    const claimedAtMs = Date.now();
    transaction.set(
      queueRef,
      {
        status: "sending",
        claimedVersion: expectedVersion,
        claimedAt: admin.firestore.Timestamp.fromMillis(claimedAtMs),
        leaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          claimedAtMs + DISPATCH_LEASE_MS
        ),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { ...data, claimedVersion: expectedVersion };
  });
}

async function dispatchNotification(queueRef, queueData) {
  let sendResult;
  try {
    sendResult = await sendNotificationForQueue(queueData);
  } catch (error) {
    await releaseFailedClaim(queueRef, queueData.claimedVersion, error);
    throw error;
  }

  await finalizeNotificationDispatch(
    queueRef,
    queueData.claimedVersion,
    sendResult
  );
}

async function finalizeNotificationDispatch(queueRef, claimedVersion, sendResult) {
  await db.runTransaction(async (transaction) => {
    const currentSnap = await transaction.get(queueRef);
    if (!currentSnap.exists) return;

    const current = currentSnap.data() || {};
    // A newer message arrived while FCM was sending. Its pending state owns the
    // queue now, so the older dispatch must never clear or overwrite it.
    if (!shouldFinalizeClaim(current, claimedVersion)) {
      return;
    }

    const nowMs = Date.now();
    const update = {
      pendingCount: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(
        nowMs + QUEUE_RETENTION_MS
      ),
      sentDeviceCount: sendResult.sentCount,
      failedDeviceCount: sendResult.failedCount,
      suppressedDeviceCount: sendResult.suppressedCount,
      lastDispatchReason:
        sendResult.reason || admin.firestore.FieldValue.delete(),
      claimedVersion: admin.firestore.FieldValue.delete(),
      claimedAt: admin.firestore.FieldValue.delete(),
      leaseExpiresAt: admin.firestore.FieldValue.delete(),
    };

    if (sendResult.sentCount > 0) {
      update.status = "sent";
      update.lastSentAt = admin.firestore.FieldValue.serverTimestamp();
      update.lastSuppressedAt = admin.firestore.FieldValue.delete();
      update.lastDroppedAt = admin.firestore.FieldValue.delete();
      transaction.set(queueRef, update, { merge: true });
      return;
    }

    if (sendResult.suppressedCount > 0 && sendResult.eligibleCount === 0) {
      update.status = "suppressed";
      update.lastSuppressedAt = admin.firestore.FieldValue.serverTimestamp();
      update.lastDroppedAt = admin.firestore.FieldValue.delete();
      transaction.set(queueRef, update, { merge: true });
      return;
    }

    update.status = "dropped";
    update.lastDroppedAt = admin.firestore.FieldValue.serverTimestamp();
    transaction.set(queueRef, update, { merge: true });
  });
}

async function releaseFailedClaim(queueRef, claimedVersion, error) {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(queueRef);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (
      data.status !== "sending" ||
      (toInt(data.version) || 0) !== claimedVersion
    ) {
      return;
    }

    transaction.set(
      queueRef,
      {
        status: "pending",
        scheduledAt: admin.firestore.Timestamp.fromMillis(Date.now() + 1000),
        version: claimedVersion + 1,
        lastDispatchReason: cleanString(error?.code) || "dispatch_error",
        claimedVersion: admin.firestore.FieldValue.delete(),
        claimedAt: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

async function sendNotificationForQueue(queueData) {
  if (
    await isChatSenderMuted(
      cleanString(queueData.recipientUid),
      cleanString(queueData.senderUid)
    )
  ) {
    return {
      sentCount: 0,
      failedCount: 0,
      suppressedCount: 1,
      eligibleCount: 0,
      reason: "muted_sender",
    };
  }

  let devicesSnap = await db
    .collection("users")
    .doc(queueData.recipientUid)
    .collection("notificationDevices")
    .get();

  // Transitional fallback for app versions that still store push fields in
  // the public E2EE device document. The migration job removes these fields,
  // after which this path naturally becomes empty and can be retired.
  if (devicesSnap.empty) {
    devicesSnap = await db
      .collection("users")
      .doc(queueData.recipientUid)
      .collection("devices")
      .get();
  }

  if (devicesSnap.empty) {
    return {
      sentCount: 0,
      failedCount: 0,
      suppressedCount: 0,
      eligibleCount: 0,
      reason: "no_devices",
    };
  }

  let deviceStatuses = {};
  try {
    const statusSnap = await admin
      .database()
      .ref(`status/${queueData.recipientUid}/devices`)
      .get();
    deviceStatuses = statusSnap.val() || {};
  } catch (_) {}

  const { title, body } = buildNotificationText(queueData);
  const outbound = [];
  let suppressedCount = 0;
  let eligibleCount = 0;

  for (const doc of devicesSnap.docs) {
    const deviceData = doc.data() || {};
    if (isDeviceInactiveForDelivery(deviceData)) {
      continue;
    }

    const token = cleanString(deviceData.fcmToken);
    if (!token) continue;

    const status = deviceStatuses[doc.id] || {};
    const isForeground =
      status.online === true && cleanString(status.appState) === "foreground";
    const isSuppressed =
      isForeground &&
      (cleanString(status.screen) === "chat_list" ||
        (cleanString(status.screen) === "chat_room" &&
          cleanString(status.roomId) === cleanString(queueData.roomId)));

    if (isSuppressed) {
      suppressedCount += 1;
      continue;
    }

    if (isForeground) {
      eligibleCount += 1;
      outbound.push({
        docRef: doc.ref,
        message: buildForegroundMessage(queueData, token, title, body),
      });
      continue;
    }

    if (deviceData.pushEnabled !== true) {
      continue;
    }

    eligibleCount += 1;
    outbound.push({
      docRef: doc.ref,
      message: buildPushMessage(queueData, token, title, body),
    });
  }

  if (outbound.length === 0) {
    return {
      sentCount: 0,
      failedCount: 0,
      suppressedCount,
      eligibleCount,
      reason:
        suppressedCount > 0 ? "suppressed_in_app" : "no_eligible_devices",
    };
  }

  const results = await Promise.allSettled(
    outbound.map((entry) => admin.messaging().send(entry.message))
  );

  await cleanupInvalidTokens(outbound, results);

  const sentCount = results.filter((result) => result.status === "fulfilled")
    .length;

  return {
    sentCount,
    failedCount: results.length - sentCount,
    suppressedCount,
    eligibleCount,
    reason: sentCount > 0 ? null : "all_sends_failed",
  };
}

function buildForegroundMessage(queueData, token, title, body) {
  return {
    token,
    data: buildDataPayload(queueData, title, body, DELIVERY_MODE_FOREGROUND),
    android: {
      priority: "high",
    },
    apns: {
      headers: {
        "apns-priority": "5",
        "apns-push-type": "background",
        "apns-collapse-id": cleanString(queueData.roomId),
      },
      payload: {
        aps: {
          contentAvailable: true,
        },
      },
    },
  };
}

function buildPushMessage(queueData, token, title, body) {
  return {
    token,
    data: buildDataPayload(queueData, title, body, DELIVERY_MODE_PUSH),
    android: {
      priority: "high",
      collapseKey: `chat_${cleanString(queueData.roomId)}`,
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
        "apns-collapse-id": cleanString(queueData.roomId),
      },
      payload: {
        aps: {
          alert: {
            title,
            body,
          },
          sound: "default",
        },
      },
    },
  };
}

function buildDataPayload(queueData, title, body, deliveryMode) {
  return {
    type: "chat_message",
    roomId: cleanString(queueData.roomId),
    senderUid: cleanString(queueData.senderUid),
    senderName: cleanString(queueData.senderName),
    messageId: cleanString(queueData.lastMessageId),
    pendingCount: String(toInt(queueData.pendingCount) || 1),
    deliveryMode,
    title,
    body,
  };
}

function buildNotificationText(queueData) {
  const senderName = cleanString(queueData.senderName) || "MatchU";
  const pendingCount = toInt(queueData.pendingCount) || 1;
  const title = pendingCount > 1 ? `${senderName} (${pendingCount})` : senderName;
  const body = resolveQueuedPreview(queueData);

  return {
    title,
    body,
  };
}

function extractMessagePreview(messageData, messageType) {
  const directPreview = truncateNotificationText(
    cleanString(messageData.notificationPreview)
  );
  if (directPreview) {
    return directPreview;
  }

  if (messageType === "image") {
    return "\u0110\u00E3 g\u1EEDi m\u1ED9t \u1EA3nh";
  }

  if (messageType === "post_share") {
    return "Đã chia sẻ một bài viết";
  }

  const plaintext = truncateNotificationText(cleanString(messageData.text));
  if (plaintext) {
    return plaintext;
  }

  return "\u0110\u00E3 g\u1EEDi m\u1ED9t tin nh\u1EAFn m\u1EDBi";
}

function resolveQueuedPreview(queueData) {
  const messageType = cleanString(queueData.lastMessageType);
  const preview = truncateNotificationText(cleanString(queueData.lastMessagePreview));
  if (preview) {
    return preview;
  }

  if (messageType === "image") {
    return "\u0110\u00E3 g\u1EEDi m\u1ED9t \u1EA3nh";
  }

  if (messageType === "post_share") {
    return "Đã chia sẻ một bài viết";
  }

  return "\u0110\u00E3 g\u1EEDi m\u1ED9t tin nh\u1EAFn m\u1EDBi";
}

function truncateNotificationText(value) {
  if (!value) return "";
  if (value.length <= MAX_NOTIFICATION_PREVIEW_LENGTH) {
    return value;
  }
  return `${value.slice(0, MAX_NOTIFICATION_PREVIEW_LENGTH).trimEnd()}...`;
}

function isDeviceInactiveForDelivery(deviceData) {
  const status =
    cleanString(deviceData.status) || cleanString(deviceData.e2eeStatus);
  return status === "inactive" || status === "revoked" || status === "stale";
}

async function isChatSenderMuted(recipientUid, senderUid) {
  if (!recipientUid || !senderUid || recipientUid === senderUid) return false;

  const muteRef = db
    .collection("users")
    .doc(recipientUid)
    .collection("mutedChatUsers")
    .doc(senderUid);
  const muteSnap = await muteRef.get();
  if (!muteSnap.exists) return false;

  const muteData = muteSnap.data() || {};
  if (isChatMuteActive(muteData, Date.now())) return true;

  // Timed mute documents are removed lazily after expiry.
  await muteRef.delete().catch(() => {});
  return false;
}

function isChatMuteActive(muteData, nowMs) {
  if (!muteData) return false;
  if (muteData.mutedUntil == null) return true;
  return timestampToMillis(muteData.mutedUntil) > nowMs;
}

async function computeSenderDelayMs(senderUid, nowMs) {
  const rateLimitRef = db.collection(SENDER_RATE_LIMIT_COLLECTION).doc(senderUid);

  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(rateLimitRef);
    const data = snap.exists ? snap.data() || {} : {};
    const timestamps = Array.isArray(data.timestampsMs) ? data.timestampsMs : [];

    const recent = timestamps
      .map((value) => toInt(value))
      .filter((value) => value && nowMs - value <= RATE_LIMIT_WINDOW_MS);

    recent.push(nowMs);

    transaction.set(
      rateLimitRef,
      {
        timestampsMs: recent.slice(-20),
        updatedAt: admin.firestore.Timestamp.fromMillis(nowMs),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          nowMs + RATE_LIMIT_RETENTION_MS
        ),
      },
      { merge: true }
    );

    return recent.length > RATE_LIMIT_MAX_MESSAGES ? RATE_LIMIT_WINDOW_MS : 0;
  });
}

const maintainChatNotificationQueues = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Bangkok",
    region: REGION,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    await Promise.all([
      recoverExpiredClaims(now),
      deleteExpiredDocuments(NOTIFICATION_QUEUE_COLLECTION, now),
      deleteExpiredDocuments(SENDER_RATE_LIMIT_COLLECTION, now),
    ]);
  }
);

async function recoverExpiredClaims(now) {
  const snap = await db
    .collection(NOTIFICATION_QUEUE_COLLECTION)
    .where("status", "==", "sending")
    .where("leaseExpiresAt", "<=", now)
    .limit(MAINTENANCE_BATCH_SIZE)
    .get();

  if (snap.empty) return 0;
  const batch = db.batch();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    batch.set(
      doc.ref,
      {
        status: "pending",
        scheduledAt: now,
        version: (toInt(data.version) || 0) + 1,
        lastDispatchReason: "dispatch_lease_expired",
        claimedVersion: admin.firestore.FieldValue.delete(),
        claimedAt: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();
  return snap.size;
}

async function deleteExpiredDocuments(collectionName, now) {
  const snap = await db
    .collection(collectionName)
    .where("expiresAt", "<=", now)
    .limit(MAINTENANCE_BATCH_SIZE)
    .get();
  if (snap.empty) return 0;

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snap.size;
}

async function cleanupInvalidTokens(outbound, results) {
  const batch = db.batch();
  let hasWrite = false;

  results.forEach((result, index) => {
    if (result.status === "fulfilled") return;

    const code =
      result.reason?.errorInfo?.code || result.reason?.code || "";

    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      batch.set(
        outbound[index].docRef,
        {
          fcmToken: admin.firestore.FieldValue.delete(),
          pushEnabled: false,
          notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      hasWrite = true;
    }
  });

  if (hasWrite) {
    await batch.commit();
  }
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function toInt(value) {
  if (Number.isInteger(value)) return value;
  if (typeof value === "number") return Math.trunc(value);
  if (typeof value === "string" && value.trim()) {
    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const intValue = toInt(value);
  return intValue || 0;
}

function shouldFinalizeClaim(queueData, claimedVersion) {
  return (
    (toInt(queueData?.version) || 0) === claimedVersion &&
    queueData?.status === "sending" &&
    (toInt(queueData?.claimedVersion) || 0) === claimedVersion
  );
}

async function waitUntil(timestamp) {
  const delayMs = Math.max(0, timestampToMillis(timestamp) - Date.now());
  if (delayMs <= 0) return;
  await sleep(delayMs);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = {
  queueChatMessageNotification,
  dispatchQueuedChatNotification,
  maintainChatNotificationQueues,
  __test: {
    isChatMuteActive,
    isDeviceInactiveForDelivery,
    shouldFinalizeClaim,
    truncateNotificationText,
  },
};
