const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");

const { admin, db } = require("../src/shared/firebase");
const { normalizeTimezone, resolveDateKey } = require("../utils/dateKey");
const {
  REPUTATION_DAILY_CAP,
  DEFAULT_REPUTATION_TIMEZONE,
  FIVE_STAR_RATING_TASK_ID,
  MUTUAL_LIKE_LONG_CHAT_TASK_ID,
  QUALIFIED_DAILY_POST_TASK_ID,
  getTaskConfig,
} = require("./taskConfig");
const {
  toInt,
  toMillis,
  normalizeDailyDoc,
  getCurrentReputationScore,
  resolveTaskProgressCap,
} = require("./types");

const TEMP_CHAT_TASK_ID = "tempChat3Rooms3Minutes";
const TEMP_CHAT_COMPLETION_LOGS_SUBCOLLECTION = "tempChatCompletionLogs";
const TEMP_CHAT_MIN_DURATION_MS = 3 * 60 * 1000;
const TEMP_CHAT_FINAL_STATUSES = new Set(["ended", "converted"]);
const FIVE_STAR_RATING_COMPLETION_LOGS_SUBCOLLECTION =
  "fiveStarRatingCompletionLogs";
const FIVE_STAR_RATING_MIN_SCORE = 5;
const MUTUAL_LIKE_LONG_CHAT_COMPLETION_LOGS_SUBCOLLECTION =
  "mutualLikeLongChatCompletionLogs";
const QUALIFIED_DAILY_POST_COMPLETION_LOGS_SUBCOLLECTION =
  "qualifiedDailyPostCompletionLogs";
const QUALIFIED_DAILY_POST_MIN_CONTENT_LENGTH = 16;
const QUALIFIED_DAILY_POST_MEDIA_TYPES = new Set(["image", "video", "audio"]);

function normalizeParticipants(rawParticipants, userA, userB) {
  const participants = [];

  if (Array.isArray(rawParticipants)) {
    for (const uid of rawParticipants) {
      if (typeof uid !== "string") continue;
      const normalizedUid = uid.trim();
      if (!normalizedUid || participants.includes(normalizedUid)) continue;
      participants.push(normalizedUid);
    }
  }

  for (const uid of [userA, userB]) {
    if (typeof uid !== "string") continue;
    const normalizedUid = uid.trim();
    if (!normalizedUid || participants.includes(normalizedUid)) continue;
    participants.push(normalizedUid);
  }

  return participants;
}

function shouldHandleTempChatCompletion(beforeRoom, afterRoom) {
  const beforeStatus =
    typeof beforeRoom?.status === "string" ? beforeRoom.status : "";
  const afterStatus =
    typeof afterRoom?.status === "string" ? afterRoom.status : "";

  if (!TEMP_CHAT_FINAL_STATUSES.has(afterStatus)) return false;
  if (TEMP_CHAT_FINAL_STATUSES.has(beforeStatus)) return false;
  return true;
}

function shouldHandleMutualLikeLongChatConversion(beforeRoom, afterRoom) {
  const beforeStatus =
    typeof beforeRoom?.status === "string" ? beforeRoom.status : "";
  const afterStatus =
    typeof afterRoom?.status === "string" ? afterRoom.status : "";

  if (afterStatus !== "converted") return false;
  if (beforeStatus === "converted") return false;

  const permanentRoomId =
    typeof afterRoom?.permanentRoomId === "string"
      ? afterRoom.permanentRoomId.trim()
      : "";
  if (!permanentRoomId) return false;

  return true;
}

function hasMutualLikes(roomData) {
  return roomData?.userALiked === true && roomData?.userBLiked === true;
}

function resolveTempChatEndMillis(event, beforeRoom, afterRoom) {
  const afterEndedAtMs = toMillis(afterRoom?.endedAt);
  if (afterEndedAtMs != null) return afterEndedAtMs;

  const snapshotUpdateMs = toMillis(event?.data?.after?.updateTime);
  if (snapshotUpdateMs != null) return snapshotUpdateMs;

  const beforeEndedAtMs = toMillis(beforeRoom?.endedAt);
  if (beforeEndedAtMs != null) return beforeEndedAtMs;

  return Date.now();
}

function buildDailyRef(uid, dateKey) {
  return db.collection("users").doc(uid).collection("reputationDaily").doc(dateKey);
}

function serializeTasksForWrite(tasks) {
  const out = {};

  for (const [taskId, task] of Object.entries(tasks)) {
    out[taskId] = {
      target: task.target,
      progress: task.progress,
      reward: task.reward,
      claimed: task.claimed,
      claimedReward: task.claimedReward,
      claimedAt: task.claimedAt || null,
    };
  }

  return out;
}

function hasQualifiedPostContent(content) {
  if (typeof content !== "string") return false;
  return content.trim().length >= QUALIFIED_DAILY_POST_MIN_CONTENT_LENGTH;
}

function hasQualifiedPostMedia(media) {
  if (!Array.isArray(media)) return false;

  return media.some((item) => {
    if (!item || typeof item !== "object") return false;
    const url = typeof item.url === "string" ? item.url.trim() : "";
    const type =
      typeof item.type === "string" ? item.type.trim().toLowerCase() : "";
    return url.length > 0 && QUALIFIED_DAILY_POST_MEDIA_TYPES.has(type);
  });
}

function isQualifiedDailyPost(post) {
  if (!post || typeof post !== "object") return false;
  if (post.deletedAt != null) return false;
  if (!isModerationApproved(post)) return false;

  const authorId = toSafeUid(post.authorId);
  if (!authorId) return false;

  const postType =
    typeof post.postType === "string" ? post.postType.trim().toLowerCase() : "";
  if (postType === "repost") return false;

  return (
    hasQualifiedPostContent(post.content) &&
    hasQualifiedPostMedia(post.media)
  );
}

function isModerationApproved(post) {
  const status =
    typeof post?.moderationStatus === "string"
      ? post.moderationStatus.trim().toLowerCase()
      : "";
  return !status || status === "approved";
}

function buildDailyWritePayload({ daily, includeCreatedAt }) {
  const payload = {
    dateKey: daily.dateKey,
    timezone: daily.timezone,
    cap: daily.cap,
    claimedPoints: daily.claimedPoints,
    tasks: serializeTasksForWrite(daily.tasks),
    runtime: daily.runtime,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (includeCreatedAt) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  return payload;
}

async function applyTempChatCompletionProgress({ uid, roomId, completedAtMs }) {
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const timezone = normalizeTimezone(
      userData?.reputationTimezone,
      DEFAULT_REPUTATION_TIMEZONE
    );
    const completedAt = new Date(completedAtMs);
    const dateKey = resolveDateKey({ timeZone: timezone, now: completedAt });
    const dailyRef = buildDailyRef(uid, dateKey);
    const completionLogRef = dailyRef
      .collection(TEMP_CHAT_COMPLETION_LOGS_SUBCOLLECTION)
      .doc(roomId);

    const [dailySnap, completionLogSnap] = await Promise.all([
      tx.get(dailyRef),
      tx.get(completionLogRef),
    ]);

    if (completionLogSnap.exists) return;

    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    let daily = normalizeDailyDoc(rawDaily, { dateKey, timezone });

    const task = daily.tasks[TEMP_CHAT_TASK_ID];
    if (!task) return;

    const nextProgress = Math.min(task.target, task.progress + 1);
    const didIncrement = nextProgress !== task.progress;

    if (didIncrement) {
      daily = {
        ...daily,
        tasks: {
          ...daily.tasks,
          [TEMP_CHAT_TASK_ID]: {
            ...task,
            progress: nextProgress,
          },
        },
      };
    }

    tx.set(
      dailyRef,
      buildDailyWritePayload({
        daily,
        includeCreatedAt: !dailySnap.exists,
      }),
      { merge: true }
    );

    tx.set(completionLogRef, {
      roomId,
      uid,
      taskId: TEMP_CHAT_TASK_ID,
      counted: didIncrement,
      completedAtMillis: completedAtMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function applyMutualLikeLongChatProgress({
  uid,
  roomId,
  convertedAtMs,
}) {
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const timezone = normalizeTimezone(
      userData?.reputationTimezone,
      DEFAULT_REPUTATION_TIMEZONE
    );
    const convertedAt = new Date(convertedAtMs);
    const dateKey = resolveDateKey({ timeZone: timezone, now: convertedAt });
    const dailyRef = buildDailyRef(uid, dateKey);
    const completionLogRef = dailyRef
      .collection(MUTUAL_LIKE_LONG_CHAT_COMPLETION_LOGS_SUBCOLLECTION)
      .doc(roomId);

    const [dailySnap, completionLogSnap] = await Promise.all([
      tx.get(dailyRef),
      tx.get(completionLogRef),
    ]);

    if (completionLogSnap.exists) return;

    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    let daily = normalizeDailyDoc(rawDaily, { dateKey, timezone });

    const task = daily.tasks[MUTUAL_LIKE_LONG_CHAT_TASK_ID];
    if (!task) return;

    const nextProgress = Math.min(task.target, task.progress + 1);
    const didIncrement = nextProgress !== task.progress;

    if (didIncrement) {
      daily = {
        ...daily,
        tasks: {
          ...daily.tasks,
          [MUTUAL_LIKE_LONG_CHAT_TASK_ID]: {
            ...task,
            progress: nextProgress,
          },
        },
      };
    }

    tx.set(
      dailyRef,
      buildDailyWritePayload({
        daily,
        includeCreatedAt: !dailySnap.exists,
      }),
      { merge: true }
    );

    tx.set(completionLogRef, {
      roomId,
      uid,
      taskId: MUTUAL_LIKE_LONG_CHAT_TASK_ID,
      counted: didIncrement,
      convertedAtMillis: convertedAtMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

function resolveRatingCreatedAtMillis(event, ratingData) {
  const snapshotCreatedAtMs = toMillis(event?.data?.createTime);
  if (snapshotCreatedAtMs != null) return snapshotCreatedAtMs;

  const ratingCreatedAtMs = toMillis(ratingData?.createdAt);
  if (ratingCreatedAtMs != null) return ratingCreatedAtMs;

  return Date.now();
}

function toSafeUid(rawUid) {
  return typeof rawUid === "string" ? rawUid.trim() : "";
}

async function applyReceivedFiveStarRatingProgress({
  toUid,
  fromUid,
  ratingId,
  score,
  ratedAtMs,
}) {
  const userRef = db.collection("users").doc(toUid);
  const taskConfig = getTaskConfig(FIVE_STAR_RATING_TASK_ID);
  if (!taskConfig) return;

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const timezone = normalizeTimezone(
      userData?.reputationTimezone,
      DEFAULT_REPUTATION_TIMEZONE
    );
    const ratedAt = new Date(ratedAtMs);
    const dateKey = resolveDateKey({ timeZone: timezone, now: ratedAt });
    const dailyRef = buildDailyRef(toUid, dateKey);
    const completionLogRef = dailyRef
      .collection(FIVE_STAR_RATING_COMPLETION_LOGS_SUBCOLLECTION)
      .doc(ratingId);

    const [dailySnap, completionLogSnap] = await Promise.all([
      tx.get(dailyRef),
      tx.get(completionLogRef),
    ]);
    if (completionLogSnap.exists) return;

    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    let daily = normalizeDailyDoc(rawDaily, { dateKey, timezone });

    const task = daily.tasks[FIVE_STAR_RATING_TASK_ID];
    let didIncrement = false;
    if (task) {
      const progressCap = resolveTaskProgressCap(taskConfig, task.target);
      const nextProgress = Math.min(progressCap, task.progress + 1);
      didIncrement = nextProgress !== task.progress;

      if (didIncrement) {
        daily = {
          ...daily,
          tasks: {
            ...daily.tasks,
            [FIVE_STAR_RATING_TASK_ID]: {
              ...task,
              progress: nextProgress,
            },
          },
        };
      }
    }

    tx.set(
      dailyRef,
      buildDailyWritePayload({
        daily,
        includeCreatedAt: !dailySnap.exists,
      }),
      { merge: true }
    );

    tx.set(completionLogRef, {
      ratingId,
      taskId: FIVE_STAR_RATING_TASK_ID,
      fromUid,
      toUid,
      score,
      counted: didIncrement,
      ratedAtMillis: ratedAtMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function applyQualifiedDailyPostProgress({ uid, postId, postedAtMs }) {
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const timezone = normalizeTimezone(
      userData?.reputationTimezone,
      DEFAULT_REPUTATION_TIMEZONE
    );
    const postedAt = new Date(postedAtMs);
    const dateKey = resolveDateKey({ timeZone: timezone, now: postedAt });
    const dailyRef = buildDailyRef(uid, dateKey);
    const completionLogRef = dailyRef
      .collection(QUALIFIED_DAILY_POST_COMPLETION_LOGS_SUBCOLLECTION)
      .doc(postId);

    const [dailySnap, completionLogSnap] = await Promise.all([
      tx.get(dailyRef),
      tx.get(completionLogRef),
    ]);

    if (completionLogSnap.exists) return;

    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    let daily = normalizeDailyDoc(rawDaily, { dateKey, timezone });

    const task = daily.tasks[QUALIFIED_DAILY_POST_TASK_ID];
    if (!task) return;

    const nextProgress = Math.min(task.target, task.progress + 1);
    const didIncrement = nextProgress !== task.progress;

    if (didIncrement) {
      daily = {
        ...daily,
        tasks: {
          ...daily.tasks,
          [QUALIFIED_DAILY_POST_TASK_ID]: {
            ...task,
            progress: nextProgress,
          },
        },
      };
    }

    tx.set(
      dailyRef,
      buildDailyWritePayload({
        daily,
        includeCreatedAt: !dailySnap.exists,
      }),
      { merge: true }
    );

    tx.set(completionLogRef, {
      postId,
      uid,
      taskId: QUALIFIED_DAILY_POST_TASK_ID,
      counted: didIncrement,
      postedAtMillis: postedAtMs,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

function resolvePostCreatedAtMillis(event, postData) {
  const postCreatedAtMs = toMillis(postData?.createdAt);
  if (postCreatedAtMs != null) return postCreatedAtMs;

  const snapshotCreatedAtMs = toMillis(event?.data?.createTime);
  if (snapshotCreatedAtMs != null) return snapshotCreatedAtMs;

  return Date.now();
}

const progressTempChat3Rooms3MinutesTask = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const beforeRoom = event.data.before.data();
    const afterRoom = event.data.after.data();
    if (!afterRoom) return;

    if (!shouldHandleTempChatCompletion(beforeRoom, afterRoom)) return;

    const startedAtMs =
      toMillis(afterRoom.createdAt) ?? toMillis(beforeRoom?.createdAt);
    if (startedAtMs == null) return;

    const completedAtMs = resolveTempChatEndMillis(event, beforeRoom, afterRoom);
    const durationMs = Math.max(0, completedAtMs - startedAtMs);
    if (durationMs < TEMP_CHAT_MIN_DURATION_MS) return;

    const participants = normalizeParticipants(
      afterRoom.participants,
      afterRoom.userA,
      afterRoom.userB
    );
    if (participants.length === 0) return;

    const roomId = event.params.roomId;
    for (const uid of participants) {
      await applyTempChatCompletionProgress({
        uid,
        roomId,
        completedAtMs,
      });
    }
  }
);

const progressMutualLikeLongChat5TimesTask = onDocumentUpdated(
  "tempChats/{roomId}",
  async (event) => {
    const beforeRoom = event.data.before.data();
    const afterRoom = event.data.after.data();
    if (!afterRoom) return;

    if (!shouldHandleMutualLikeLongChatConversion(beforeRoom, afterRoom)) {
      return;
    }
    if (!hasMutualLikes(afterRoom)) return;

    const participants = normalizeParticipants(
      afterRoom.participants,
      afterRoom.userA,
      afterRoom.userB
    );
    if (participants.length === 0) return;

    const roomId = event.params.roomId;
    const convertedAtMs = resolveTempChatEndMillis(event, beforeRoom, afterRoom);
    for (const uid of participants) {
      await applyMutualLikeLongChatProgress({
        uid,
        roomId,
        convertedAtMs,
      });
    }
  }
);

const progressReceivedFiveStarRatingTask = onDocumentCreated(
  "chatRatings/{ratingId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const rating = snap.data() || {};
    const toUid = toSafeUid(rating.toUid);
    const fromUid = toSafeUid(rating.fromUid);
    if (!toUid || !fromUid) return;
    if (toUid === fromUid) return;
    if (rating.skipped === true) return;

    const score = Number(rating.score);
    if (!Number.isFinite(score) || score < FIVE_STAR_RATING_MIN_SCORE) {
      return;
    }

    const ratingId = event.params.ratingId;
    const ratedAtMs = resolveRatingCreatedAtMillis(event, rating);

    await applyReceivedFiveStarRatingProgress({
      toUid,
      fromUid,
      ratingId,
      score,
      ratedAtMs,
    });
  }
);

const progressQualifiedDailyPostTask = onDocumentWritten(
  "posts/{postId}",
  async (event) => {
    const afterSnap = event.data?.after;
    if (!afterSnap?.exists) return;

    const post = afterSnap.data() || {};
    if (!isQualifiedDailyPost(post)) return;

    const beforeSnap = event.data?.before;
    if (beforeSnap?.exists && isQualifiedDailyPost(beforeSnap.data() || {})) {
      return;
    }

    const uid = toSafeUid(post.authorId);
    if (!uid) return;

    const postId = event.params.postId;
    const postedAtMs = resolvePostCreatedAtMillis(event, post);

    await applyQualifiedDailyPostProgress({
      uid,
      postId,
      postedAtMs,
    });
  }
);

const ensureUserReputationDailyDefaults = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const userData = snap.data() || {};
    const reputationScore = getCurrentReputationScore(userData);
    const hasOwn = (key) => Object.prototype.hasOwnProperty.call(userData, key);

    const patch = {};

    if (!hasOwn("reputationScore") ||
        toInt(userData.reputationScore, reputationScore) !== reputationScore) {
      patch.reputationScore = reputationScore;
    }
    if (!hasOwn("reputation") ||
        toInt(userData.reputation, reputationScore) !== reputationScore) {
      patch.reputation = reputationScore;
    }

    if (!hasOwn("reputationTodayDateKey")) {
      patch.reputationTodayDateKey = null;
    } else if (
      userData.reputationTodayDateKey != null &&
      typeof userData.reputationTodayDateKey !== "string"
    ) {
      patch.reputationTodayDateKey = null;
    }

    const todayClaimedRaw = toInt(userData.reputationTodayClaimed, 0);
    const todayClaimed = Math.max(0, todayClaimedRaw);
    if (!hasOwn("reputationTodayClaimed") || todayClaimedRaw !== todayClaimed) {
      patch.reputationTodayClaimed = todayClaimed;
    }

    const todayCapRaw = toInt(userData.reputationTodayCap, REPUTATION_DAILY_CAP);
    const todayCap = Math.max(1, todayCapRaw);
    if (!hasOwn("reputationTodayCap") || todayCapRaw !== todayCap) {
      patch.reputationTodayCap = todayCap;
    }

    if (!hasOwn("reputationLastClaimAt")) {
      patch.reputationLastClaimAt = null;
    }

    if (Object.keys(patch).length === 0) {
      return;
    }

    patch.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    await snap.ref.set(patch, { merge: true });
  }
);

module.exports = {
  ensureUserReputationDailyDefaults,
  progressTempChat3Rooms3MinutesTask,
  progressMutualLikeLongChat5TimesTask,
  progressReceivedFiveStarRatingTask,
  progressQualifiedDailyPostTask,
};
