const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");

const REGION = "asia-southeast1";
const PUSH_QUEUE_COLLECTION = "postEngagementNotificationQueues";
const INITIAL_AGGREGATION_DELAY_MS = 8 * 1000;
const MIN_PUSH_GAP_MS = 45 * 1000;
const DISPATCH_LEASE_MS = 60 * 1000;
const QUEUE_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
const MAINTENANCE_BATCH_SIZE = 200;

function cleanString(value, maxLength = 160) {
  if (typeof value !== "string") return "";
  return value.trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function toSafeUid(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildActorProfile(userId, data) {
  const fullname = cleanString(data?.fullname, 80);
  const nickname = cleanString(data?.nickname, 80);
  return {
    actorId: userId,
    actorName: fullname || nickname || "Người dùng MatchU",
    actorNickname: nickname,
    actorAvatarUrl: cleanString(data?.avatarUrl, 500),
    actorIsVerified: data?.isFaceVerified === true,
  };
}

async function loadActorProfile(userId) {
  if (!userId) {
    return buildActorProfile("", null);
  }

  const snap = await db.collection("users").doc(userId).get();
  return buildActorProfile(userId, snap.exists ? snap.data() : null);
}

function postPreview(postData) {
  const content = cleanString(postData?.content, 80);
  if (content) return content;

  const media = Array.isArray(postData?.media) ? postData.media : [];
  if (media.length > 0) return "bài viết có đính kèm nội dung đa phương tiện";
  return "bài viết của bạn";
}

function notificationRef(userId, notificationId) {
  return db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc(notificationId);
}

async function isNotificationAuthorMuted(userId, actorId) {
  if (!userId || !actorId) return false;

  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("mutedNotificationAuthors")
    .doc(actorId)
    .get();

  return snap.exists;
}

async function createNotification(userId, notificationId, payload) {
  if (!userId || !notificationId) return;

  await notificationRef(userId, notificationId).set(
    {
      ...payload,
      recipientId: userId,
      readAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

const createPostLikeNotification = onDocumentCreated(
  "posts/{postId}/likes/{userId}",
  async (event) => {
    const postId = cleanString(event.params.postId, 120);
    const actorId =
      toSafeUid(event.data?.data()?.userId) || toSafeUid(event.params.userId);
    if (!postId || !actorId) return;

    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) return;

    const post = postSnap.data() || {};
    const recipientId = toSafeUid(post.authorId);
    if (!recipientId || recipientId === actorId) return;
    if (await isNotificationAuthorMuted(recipientId, actorId)) return;

    const actor = await loadActorProfile(actorId);
    await createNotification(
      recipientId,
      `post_like_${postId}_${actorId}`,
      {
        type: "post_like",
        title: `${actor.actorName} đã thích bài viết của bạn`,
        body: `Bài viết: "${postPreview(post)}"`,
        postId,
        ...actor,
      }
    );
    await queuePostEngagementPush({
      recipientId,
      postId,
      actorName: actor.actorName,
      eventType: "like",
    });
  }
);

const createPostCommentNotification = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const postId = cleanString(event.params.postId, 120);
    const commentId = cleanString(event.params.commentId, 120);
    const comment = event.data?.data() || {};
    const actorId = toSafeUid(comment.userId);
    if (!postId || !commentId || !actorId) return;

    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) return;

    const post = postSnap.data() || {};
    const actor = await loadActorProfile(actorId);
    const commentPreview =
      cleanString(comment.content, 120) ||
      (cleanString(comment.imageUrl, 10) ? "Đã bình luận bằng hình ảnh" : "") ||
      (cleanString(comment.voiceUrl, 10) ? "Đã bình luận bằng ghi âm" : "") ||
      "Đã bình luận bài viết của bạn";
    const postAuthorId = toSafeUid(post.authorId);
    const recipients = [];
    const parentId = cleanString(comment.parentId, 120);
    let parentAuthorId = "";
    if (parentId) {
      const parentSnap = await db
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .doc(parentId)
        .get();
      parentAuthorId = toSafeUid(parentSnap.data()?.userId);
    }

    if (postAuthorId && postAuthorId !== actorId) {
      const repliesToPostAuthor = parentAuthorId === postAuthorId;
      recipients.push({
        userId: postAuthorId,
        eventType: repliesToPostAuthor ? "reply" : "comment",
        title: repliesToPostAuthor
          ? `${actor.actorName} đã trả lời bình luận của bạn`
          : `${actor.actorName} đã bình luận bài viết của bạn`,
      });
    }

    if (parentAuthorId) {
      if (
        parentAuthorId &&
        parentAuthorId !== actorId &&
        parentAuthorId !== postAuthorId
      ) {
        recipients.push({
          userId: parentAuthorId,
          eventType: "reply",
          title: `${actor.actorName} đã trả lời bình luận của bạn`,
        });
      }
    }

    for (const recipient of recipients) {
      if (await isNotificationAuthorMuted(recipient.userId, actorId)) continue;
      await createNotification(
        recipient.userId,
        `post_comment_${postId}_${commentId}`,
        {
          type: "post_comment",
          title: recipient.title,
          body: commentPreview,
          postId,
          commentId,
          parentId: parentId || null,
          ...actor,
        }
      );
      await queuePostEngagementPush({
        recipientId: recipient.userId,
        postId,
        actorName: actor.actorName,
        eventType: recipient.eventType,
        commentId,
        commentPreview,
      });
    }
  }
);

async function queuePostEngagementPush({
  recipientId,
  postId,
  actorName,
  eventType,
  commentId = "",
  commentPreview = "",
}) {
  const queueRef = db
    .collection(PUSH_QUEUE_COLLECTION)
    .doc(`${recipientId}_${postId}`);
  const nowMs = Date.now();

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(queueRef);
    const current = snap.exists ? snap.data() || {} : {};
    const canAggregate = current.status === "pending";
    const likeCount = (canAggregate ? toInt(current.likeCount) : 0) +
      (eventType === "like" ? 1 : 0);
    const commentCount = (canAggregate ? toInt(current.commentCount) : 0) +
      (eventType === "comment" || eventType === "reply" ? 1 : 0);
    const pendingCount = likeCount + commentCount;
    const existingScheduleMs = timestampToMillis(current.scheduledAt);
    const lastSentAtMs = timestampToMillis(current.lastSentAt);
    const scheduledAtMs = canAggregate && existingScheduleMs > nowMs
      ? existingScheduleMs
      : Math.max(
          nowMs + INITIAL_AGGREGATION_DELAY_MS,
          lastSentAtMs + MIN_PUSH_GAP_MS
        );

    transaction.set(
      queueRef,
      {
        recipientUid: recipientId,
        postId,
        lastActorName: cleanString(actorName, 80),
        lastEventType: eventType,
        lastCommentId: cleanString(commentId, 120),
        lastCommentPreview: cleanString(commentPreview, 160),
        likeCount,
        commentCount,
        pendingCount,
        scheduledAt: admin.firestore.Timestamp.fromMillis(scheduledAtMs),
        status: "pending",
        version: (toInt(current.version) || 0) + 1,
        createdAt:
          current.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          nowMs + QUEUE_RETENTION_MS
        ),
        lastSentAt: current.lastSentAt || null,
      },
      { merge: true }
    );
  });
}

const dispatchQueuedPostEngagementNotification = onDocumentWritten(
  {
    document: `${PUSH_QUEUE_COLLECTION}/{queueId}`,
    region: REGION,
    timeoutSeconds: 120,
  },
  async (event) => {
    const after = event.data.after;
    if (!after?.exists || after.data()?.status !== "pending") return;

    const version = toInt(after.data()?.version) || 0;
    await waitUntil(after.data()?.scheduledAt);

    const claim = await claimPostEngagementPush(after.ref, version);
    if (!claim) return;

    let sendResult;
    try {
      sendResult = await sendPostEngagementPush(claim);
    } catch (error) {
      await releasePostEngagementClaim(after.ref, version, error);
      throw error;
    }
    await finalizePostEngagementPush(after.ref, version, sendResult);
  }
);

async function claimPostEngagementPush(queueRef, expectedVersion) {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(queueRef);
    if (!snap.exists) return null;
    const data = snap.data() || {};
    if (
      data.status !== "pending" ||
      (toInt(data.version) || 0) !== expectedVersion ||
      timestampToMillis(data.scheduledAt) > Date.now()
    ) {
      return null;
    }

    transaction.set(
      queueRef,
      {
        status: "sending",
        claimedVersion: expectedVersion,
        leaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + DISPATCH_LEASE_MS
        ),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ...data, claimedVersion: expectedVersion };
  });
}

async function sendPostEngagementPush(queueData) {
  let devicesSnap = await db
    .collection("users")
    .doc(queueData.recipientUid)
    .collection("notificationDevices")
    .get();
  if (devicesSnap.empty) {
    devicesSnap = await db
      .collection("users")
      .doc(queueData.recipientUid)
      .collection("devices")
      .get();
  }

  const { title, body } = buildPostEngagementText(queueData);
  const outbound = [];
  for (const doc of devicesSnap.docs) {
    const device = doc.data() || {};
    if (isDeviceInactive(device) || device.pushEnabled !== true) continue;
    const token = cleanString(device.fcmToken, 4096);
    if (!token) continue;
    outbound.push({
      docRef: doc.ref,
      message: buildPostEngagementMessage(queueData, token, title, body),
    });
  }

  if (outbound.length === 0) {
    return { sentCount: 0, failedCount: 0, reason: "no_eligible_devices" };
  }

  const results = await Promise.allSettled(
    outbound.map((entry) => admin.messaging().send(entry.message))
  );
  await cleanupInvalidPushTokens(outbound, results);
  const sentCount = results.filter((result) => result.status === "fulfilled")
    .length;
  return {
    sentCount,
    failedCount: results.length - sentCount,
    reason: sentCount > 0 ? null : "all_sends_failed",
  };
}

function buildPostEngagementMessage(queueData, token, title, body) {
  const postId = cleanString(queueData.postId, 120);
  const data = {
    type: "post_engagement",
    postId,
    commentId: cleanString(queueData.lastCommentId, 120),
    pendingCount: String(toInt(queueData.pendingCount) || 1),
    likeCount: String(toInt(queueData.likeCount) || 0),
    commentCount: String(toInt(queueData.commentCount) || 0),
    deliveryMode: "push",
    title,
    body,
  };

  return {
    token,
    data,
    android: {
      priority: "high",
      collapseKey: `post_${postId}`,
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
        "apns-collapse-id": `post_${postId}`.slice(0, 64),
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
          "thread-id": `post_${postId}`,
        },
      },
    },
  };
}

function buildPostEngagementText(queueData) {
  const likes = toInt(queueData.likeCount) || 0;
  const comments = toInt(queueData.commentCount) || 0;
  const total = likes + comments;
  const actorName = cleanString(queueData.lastActorName, 80) || "Ai \u0111\u00F3";

  if (total === 1 && likes === 1) {
    return {
      title: `${actorName} \u0111\u00E3 th\u00EDch b\u00E0i vi\u1EBFt c\u1EE7a b\u1EA1n`,
      body: "Nh\u1EA5n \u0111\u1EC3 xem b\u00E0i vi\u1EBFt.",
    };
  }
  if (total === 1 && comments === 1) {
    const isReply = cleanString(queueData.lastEventType) === "reply";
    return {
      title: isReply
        ? `${actorName} \u0111\u00E3 tr\u1EA3 l\u1EDDi b\u00ECnh lu\u1EADn c\u1EE7a b\u1EA1n`
        : `${actorName} \u0111\u00E3 b\u00ECnh lu\u1EADn b\u00E0i vi\u1EBFt c\u1EE7a b\u1EA1n`,
      body:
        cleanString(queueData.lastCommentPreview, 160) ||
        "Nh\u1EA5n \u0111\u1EC3 xem b\u00ECnh lu\u1EADn.",
    };
  }

  const parts = [];
  if (likes > 0) parts.push(`${likes} l\u01B0\u1EE3t th\u00EDch`);
  if (comments > 0) parts.push(`${comments} b\u00ECnh lu\u1EADn`);
  return {
    title: `B\u00E0i vi\u1EBFt c\u1EE7a b\u1EA1n c\u00F3 ${total} t\u01B0\u01A1ng t\u00E1c m\u1EDBi`,
    body: parts.join(" v\u00E0 "),
  };
}

async function finalizePostEngagementPush(queueRef, claimedVersion, result) {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(queueRef);
    if (!snap.exists) return;
    const current = snap.data() || {};
    if (
      current.status !== "sending" ||
      (toInt(current.version) || 0) !== claimedVersion ||
      (toInt(current.claimedVersion) || 0) !== claimedVersion
    ) {
      return;
    }

    transaction.set(
      queueRef,
      {
        status: result.sentCount > 0 ? "sent" : "dropped",
        likeCount: 0,
        commentCount: 0,
        pendingCount: 0,
        sentDeviceCount: result.sentCount,
        failedDeviceCount: result.failedCount,
        lastDispatchReason:
          result.reason || admin.firestore.FieldValue.delete(),
        lastSentAt:
          result.sentCount > 0
            ? admin.firestore.FieldValue.serverTimestamp()
            : current.lastSentAt || null,
        claimedVersion: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + QUEUE_RETENTION_MS
        ),
      },
      { merge: true }
    );
  });
}

async function releasePostEngagementClaim(queueRef, claimedVersion, error) {
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(queueRef);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (
      data.status !== "sending" ||
      (toInt(data.version) || 0) !== claimedVersion
    ) return;

    transaction.set(
      queueRef,
      {
        status: "pending",
        scheduledAt: admin.firestore.Timestamp.fromMillis(Date.now() + 1000),
        version: claimedVersion + 1,
        lastDispatchReason: cleanString(error?.code, 120) || "dispatch_error",
        claimedVersion: admin.firestore.FieldValue.delete(),
        leaseExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

const maintainPostEngagementNotificationQueues = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Bangkok",
    region: REGION,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredClaims = await db
      .collection(PUSH_QUEUE_COLLECTION)
      .where("status", "==", "sending")
      .where("leaseExpiresAt", "<=", now)
      .limit(MAINTENANCE_BATCH_SIZE)
      .get();
    if (!expiredClaims.empty) {
      const batch = db.batch();
      expiredClaims.docs.forEach((doc) => {
        const data = doc.data() || {};
        batch.set(doc.ref, {
          status: "pending",
          scheduledAt: now,
          version: (toInt(data.version) || 0) + 1,
          claimedVersion: admin.firestore.FieldValue.delete(),
          leaseExpiresAt: admin.firestore.FieldValue.delete(),
        }, { merge: true });
      });
      await batch.commit();
    }

    const expired = await db
      .collection(PUSH_QUEUE_COLLECTION)
      .where("expiresAt", "<=", now)
      .limit(MAINTENANCE_BATCH_SIZE)
      .get();
    if (!expired.empty) {
      const batch = db.batch();
      expired.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }
);

async function cleanupInvalidPushTokens(outbound, results) {
  const batch = db.batch();
  let changed = false;
  results.forEach((result, index) => {
    if (result.status === "fulfilled") return;
    const code = result.reason?.errorInfo?.code || result.reason?.code || "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      batch.set(outbound[index].docRef, {
        fcmToken: admin.firestore.FieldValue.delete(),
        pushEnabled: false,
        notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      changed = true;
    }
  });
  if (changed) await batch.commit();
}

function isDeviceInactive(device) {
  const status = cleanString(device.status) || cleanString(device.e2eeStatus);
  return status === "inactive" || status === "revoked" || status === "stale";
}

function toInt(value) {
  if (Number.isInteger(value)) return value;
  if (typeof value === "number") return Math.trunc(value);
  return Number.parseInt(value, 10) || 0;
}

function timestampToMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  return toInt(value);
}

async function waitUntil(timestamp) {
  const delayMs = Math.max(0, timestampToMillis(timestamp) - Date.now());
  if (delayMs > 0) {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
}

const createModerationPenaltyNotification = onDocumentCreated(
  "users/{userId}/postModerationViolations/{violationId}",
  async (event) => {
    const userId = toSafeUid(event.params.userId);
    const violationId = cleanString(event.params.violationId, 120);
    const violation = event.data?.data() || {};
    if (!userId || !violationId) return;

    const penalty = Number(violation.penalty || 0);
    const reason = cleanString(violation.reason, 280);
    const reputationBefore = Number(violation.reputationBefore);
    const reputationAfter = Number(violation.reputationAfter);
    const bodyParts = [];

    if (reason) bodyParts.push(reason);
    if (Number.isFinite(penalty) && penalty > 0) {
      bodyParts.push(`Bạn bị trừ ${penalty} điểm uy tín.`);
    } else {
      bodyParts.push("Vi phạm đã được ghi nhận để theo dõi uy tín.");
    }

    await createNotification(
      userId,
      `moderation_penalty_${violationId}`,
      {
        type: "moderation_penalty",
        title: "Cảnh báo tiêu chuẩn cộng đồng",
        body: bodyParts.join(" "),
        reason: reason || null,
        severity: cleanString(violation.severity, 40) || null,
        penalty: Number.isFinite(penalty) ? penalty : 0,
        reputationBefore: Number.isFinite(reputationBefore)
          ? reputationBefore
          : null,
        reputationAfter: Number.isFinite(reputationAfter)
          ? reputationAfter
          : null,
      }
    );
  }
);

module.exports = {
  createPostLikeNotification,
  createPostCommentNotification,
  createModerationPenaltyNotification,
  dispatchQueuedPostEngagementNotification,
  maintainPostEngagementNotificationQueues,
  __test: { buildPostEngagementText },
};
