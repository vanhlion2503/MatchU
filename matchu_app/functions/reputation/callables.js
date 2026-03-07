const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../src/shared/firebase");
const {
  normalizeTimezone,
  resolveDateKey,
} = require("../utils/dateKey");
const {
  DEFAULT_REPUTATION_TIMEZONE,
  REPUTATION_MAX_SCORE,
  getTaskConfig,
} = require("./taskConfig");
const {
  isPlainObject,
  toInt,
  toMillis,
  clamp,
  getCurrentReputationScore,
  normalizeDailyDoc,
  buildDailyStatePayload,
} = require("./types");

const USERS_COLLECTION = db.collection("users");
const TASK_ID_PATTERN = /^[a-zA-Z0-9_]{1,48}$/;
const DOC_ID_PATTERN = /^[a-zA-Z0-9_-]{1,120}$/;

function assertAuthenticated(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function parsePayload(data) {
  return isPlainObject(data) ? data : {};
}

function sanitizeTaskId(rawTaskId) {
  const taskId = typeof rawTaskId === "string" ? rawTaskId.trim() : "";
  if (!TASK_ID_PATTERN.test(taskId)) {
    return null;
  }
  return taskId;
}

function sanitizeDocId(rawValue, fallback) {
  const value = typeof rawValue === "string" ? rawValue.trim() : "";
  if (DOC_ID_PATTERN.test(value)) return value;
  return fallback;
}

function buildDailyRef(uid, dateKey) {
  return USERS_COLLECTION.doc(uid).collection("reputationDaily").doc(dateKey);
}

function serializeTasksForWrite(tasks, claimTimestampTaskId = null) {
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

    if (claimTimestampTaskId && taskId === claimTimestampTaskId) {
      out[taskId].claimedAt = admin.firestore.FieldValue.serverTimestamp();
    }
  }

  return out;
}

function buildDailyWritePayload({
  daily,
  includeCreatedAt,
  claimTimestampTaskId = null,
}) {
  const payload = {
    dateKey: daily.dateKey,
    timezone: daily.timezone,
    cap: daily.cap,
    claimedPoints: daily.claimedPoints,
    tasks: serializeTasksForWrite(daily.tasks, claimTimestampTaskId),
    runtime: daily.runtime,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (includeCreatedAt) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  return payload;
}

function isTaskDifferent(rawTask, normalizedTask, taskConfig) {
  const target = Math.max(1, toInt(rawTask?.target, taskConfig.target));
  const reward = Math.max(0, toInt(rawTask?.reward, taskConfig.reward));
  const progress = clamp(toInt(rawTask?.progress, 0), 0, target);
  const claimed = Boolean(rawTask?.claimed);
  const claimedReward = claimed
    ? Math.max(0, toInt(rawTask?.claimedReward, reward))
    : 0;
  const claimedAtMs = toMillis(rawTask?.claimedAt);
  const normalizedClaimedAtMs = normalizedTask.claimedAt
    ? normalizedTask.claimedAt.getTime()
    : null;

  return (
    target !== normalizedTask.target ||
    reward !== normalizedTask.reward ||
    progress !== normalizedTask.progress ||
    claimed !== normalizedTask.claimed ||
    claimedReward !== normalizedTask.claimedReward ||
    claimedAtMs !== normalizedClaimedAtMs
  );
}

function isDailyDifferent(rawDaily, normalizedDaily) {
  if (!isPlainObject(rawDaily)) return true;

  if (rawDaily.dateKey !== normalizedDaily.dateKey) return true;
  if (rawDaily.timezone !== normalizedDaily.timezone) return true;
  if (Math.max(1, toInt(rawDaily.cap, 10)) !== normalizedDaily.cap) return true;
  if (
    Math.max(0, toInt(rawDaily.claimedPoints, 0)) !== normalizedDaily.claimedPoints
  ) {
    return true;
  }

  const rawRuntime = isPlainObject(rawDaily.runtime) ? rawDaily.runtime : {};
  const rawOnlineStart =
    typeof rawRuntime.onlineSessionStartMs === "number" &&
    Number.isFinite(rawRuntime.onlineSessionStartMs)
      ? Math.trunc(rawRuntime.onlineSessionStartMs)
      : null;

  if (rawOnlineStart !== normalizedDaily.runtime.onlineSessionStartMs) {
    return true;
  }

  const rawTasks = isPlainObject(rawDaily.tasks) ? rawDaily.tasks : {};
  for (const [taskId, task] of Object.entries(normalizedDaily.tasks)) {
    const config = getTaskConfig(taskId);
    if (!config) continue;
    if (isTaskDifferent(rawTasks[taskId], task, config)) {
      return true;
    }
  }

  return false;
}

function buildUserLitePatchIfNeeded({
  userData,
  reputationScore,
  dateKey,
  todayClaimed,
  cap,
}) {
  const patch = {};

  const currentReputationScore = toInt(userData?.reputationScore, reputationScore);
  if (currentReputationScore !== reputationScore) {
    patch.reputationScore = reputationScore;
  }

  const currentReputation = toInt(userData?.reputation, reputationScore);
  if (currentReputation !== reputationScore) {
    patch.reputation = reputationScore;
  }

  const currentDateKey =
    typeof userData?.reputationTodayDateKey === "string"
      ? userData.reputationTodayDateKey
      : null;
  if (currentDateKey !== dateKey) {
    patch.reputationTodayDateKey = dateKey;
  }

  const currentClaimed = Math.max(
    0,
    toInt(userData?.reputationTodayClaimed, 0)
  );
  if (currentClaimed !== todayClaimed) {
    patch.reputationTodayClaimed = todayClaimed;
  }

  const currentCap = Math.max(1, toInt(userData?.reputationTodayCap, 10));
  if (currentCap !== cap) {
    patch.reputationTodayCap = cap;
  }

  return Object.keys(patch).length > 0 ? patch : null;
}

async function readReputationDailyState({ uid, dateKey, timezone }) {
  const userRef = USERS_COLLECTION.doc(uid);
  const dailyRef = buildDailyRef(uid, dateKey);

  const [userSnap, dailySnap] = await Promise.all([userRef.get(), dailyRef.get()]);
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const userData = userSnap.data() || {};
  const dailyData = dailySnap.exists ? dailySnap.data() : null;
  const effectiveTimezone = normalizeTimezone(
    dailyData?.timezone,
    timezone || DEFAULT_REPUTATION_TIMEZONE
  );
  const normalizedDaily = normalizeDailyDoc(dailyData, {
    dateKey,
    timezone: effectiveTimezone,
  });
  const reputationScore = getCurrentReputationScore(userData);

  return buildDailyStatePayload({ reputationScore, daily: normalizedDaily });
}

const touchReputationDailyOnAppOpen = onCall(async (request) => {
  const uid = assertAuthenticated(request);
  const payload = parsePayload(request.data);

  const timezone = normalizeTimezone(
    payload.timezone,
    DEFAULT_REPUTATION_TIMEZONE
  );
  const dateKey = resolveDateKey({
    requestedDateKey: payload.dateKey,
    timeZone: timezone,
  });
  const eventId = sanitizeDocId(
    payload.eventId,
    `loginDaily_${dateKey}_${uid.slice(0, 8)}`
  );

  const userRef = USERS_COLLECTION.doc(uid);
  const dailyRef = buildDailyRef(uid, dateKey);
  const dedupRef = dailyRef.collection("eventDedup").doc(eventId);

  await db.runTransaction(async (tx) => {
    const [userSnap, dailySnap, dedupSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(dailyRef),
      tx.get(dedupRef),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    const effectiveTimezone = normalizeTimezone(
      rawDaily?.timezone,
      timezone
    );
    let daily = normalizeDailyDoc(rawDaily, {
      dateKey,
      timezone: effectiveTimezone,
    });

    let shouldWriteDaily = !dailySnap.exists || isDailyDifferent(rawDaily, daily);

    if (!dedupSnap.exists) {
      const task = daily.tasks.loginDaily;
      if (task) {
        const nextProgress = Math.min(task.target, task.progress + 1);
        if (nextProgress !== task.progress) {
          daily = {
            ...daily,
            tasks: {
              ...daily.tasks,
              loginDaily: {
                ...task,
                progress: nextProgress,
              },
            },
          };
          shouldWriteDaily = true;
        }
      }

      tx.set(dedupRef, {
        eventId,
        taskId: "loginDaily",
        source: "app_open",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const reputationScore = getCurrentReputationScore(userData);
    const userPatch = buildUserLitePatchIfNeeded({
      userData,
      reputationScore,
      dateKey,
      todayClaimed: daily.claimedPoints,
      cap: daily.cap,
    });

    if (userPatch) {
      tx.set(userRef, userPatch, { merge: true });
    }

    if (shouldWriteDaily || !dedupSnap.exists) {
      tx.set(
        dailyRef,
        buildDailyWritePayload({
          daily,
          includeCreatedAt: !dailySnap.exists,
        }),
        { merge: true }
      );
    }
  });

  const state = await readReputationDailyState({ uid, dateKey, timezone });
  return { state };
});

const getReputationDailyState = onCall(async (request) => {
  const uid = assertAuthenticated(request);
  const payload = parsePayload(request.data);

  const timezone = normalizeTimezone(
    payload.timezone,
    DEFAULT_REPUTATION_TIMEZONE
  );
  const dateKey = resolveDateKey({
    requestedDateKey: payload.dateKey,
    timeZone: timezone,
  });

  const userRef = USERS_COLLECTION.doc(uid);
  const dailyRef = buildDailyRef(uid, dateKey);

  await db.runTransaction(async (tx) => {
    const [userSnap, dailySnap] = await Promise.all([
      tx.get(userRef),
      tx.get(dailyRef),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    const effectiveTimezone = normalizeTimezone(
      rawDaily?.timezone,
      timezone
    );
    const daily = normalizeDailyDoc(rawDaily, {
      dateKey,
      timezone: effectiveTimezone,
    });

    const shouldWriteDaily = !dailySnap.exists || isDailyDifferent(rawDaily, daily);
    if (shouldWriteDaily) {
      tx.set(
        dailyRef,
        buildDailyWritePayload({
          daily,
          includeCreatedAt: !dailySnap.exists,
        }),
        { merge: true }
      );
    }

    const reputationScore = getCurrentReputationScore(userData);
    const userPatch = buildUserLitePatchIfNeeded({
      userData,
      reputationScore,
      dateKey,
      todayClaimed: daily.claimedPoints,
      cap: daily.cap,
    });

    if (userPatch) {
      tx.set(userRef, userPatch, { merge: true });
    }
  });

  const state = await readReputationDailyState({ uid, dateKey, timezone });
  return { state };
});

const claimReputationTask = onCall(async (request) => {
  const uid = assertAuthenticated(request);
  const payload = parsePayload(request.data);

  const taskId = sanitizeTaskId(payload.taskId);
  if (!taskId || !getTaskConfig(taskId)) {
    throw new HttpsError("invalid-argument", "Invalid taskId.");
  }

  const timezone = normalizeTimezone(
    payload.timezone,
    DEFAULT_REPUTATION_TIMEZONE
  );
  const dateKey = resolveDateKey({
    requestedDateKey: payload.dateKey,
    timeZone: timezone,
  });
  const claimId = sanitizeDocId(payload.claimId, `${taskId}_${Date.now()}`);

  const userRef = USERS_COLLECTION.doc(uid);
  const dailyRef = buildDailyRef(uid, dateKey);
  const claimLogRef = dailyRef.collection("claimLogs").doc(claimId);

  let claimResult = {
    taskId,
    requested: 0,
    awarded: 0,
    reason: "unknown",
    reputationBefore: REPUTATION_MAX_SCORE,
    reputationAfter: REPUTATION_MAX_SCORE,
    todayClaimedBefore: 0,
    todayClaimedAfter: 0,
  };

  await db.runTransaction(async (tx) => {
    const [userSnap, dailySnap, claimLogSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(dailyRef),
      tx.get(claimLogRef),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const rawDaily = dailySnap.exists ? dailySnap.data() : null;
    const effectiveTimezone = normalizeTimezone(
      rawDaily?.timezone,
      timezone
    );
    let daily = normalizeDailyDoc(rawDaily, {
      dateKey,
      timezone: effectiveTimezone,
    });
    let shouldWriteDaily = !dailySnap.exists || isDailyDifferent(rawDaily, daily);

    const reputationBefore = getCurrentReputationScore(userData);
    const task = daily.tasks[taskId];
    if (!task) {
      throw new HttpsError("invalid-argument", "Task is not configured.");
    }

    claimResult = {
      taskId,
      requested: task.reward,
      awarded: 0,
      reason: "unknown",
      reputationBefore,
      reputationAfter: reputationBefore,
      todayClaimedBefore: daily.claimedPoints,
      todayClaimedAfter: daily.claimedPoints,
    };

    const patchUserLiteIfNeeded = (targetReputationScore, targetTodayClaimed) => {
      const userPatch = buildUserLitePatchIfNeeded({
        userData,
        reputationScore: targetReputationScore,
        dateKey,
        todayClaimed: targetTodayClaimed,
        cap: daily.cap,
      });
      if (userPatch) {
        tx.set(userRef, userPatch, { merge: true });
      }
    };

    if (claimLogSnap.exists) {
      const claimLog = claimLogSnap.data() || {};
      claimResult = {
        taskId,
        requested: Math.max(0, toInt(claimLog.requested, task.reward)),
        awarded: Math.max(0, toInt(claimLog.awarded, 0)),
        reason:
          typeof claimLog.reason === "string" && claimLog.reason.trim()
            ? claimLog.reason
            : "claim_request_replayed",
        reputationBefore: toInt(claimLog.reputationBefore, reputationBefore),
        reputationAfter: toInt(claimLog.reputationAfter, reputationBefore),
        todayClaimedBefore: Math.max(
          0,
          toInt(claimLog.todayClaimedBefore, daily.claimedPoints)
        ),
        todayClaimedAfter: Math.max(
          0,
          toInt(claimLog.todayClaimedAfter, daily.claimedPoints)
        ),
      };

      patchUserLiteIfNeeded(reputationBefore, daily.claimedPoints);
      if (shouldWriteDaily) {
        tx.set(
          dailyRef,
          buildDailyWritePayload({
            daily,
            includeCreatedAt: !dailySnap.exists,
          }),
          { merge: true }
        );
      }
      return;
    } else if (task.claimed) {
      claimResult.reason = "already_claimed";
      claimResult.awarded = Math.max(0, task.claimedReward);
      patchUserLiteIfNeeded(reputationBefore, daily.claimedPoints);
      if (shouldWriteDaily) {
        tx.set(
          dailyRef,
          buildDailyWritePayload({
            daily,
            includeCreatedAt: !dailySnap.exists,
          }),
          { merge: true }
        );
      }
      return;
    } else if (task.progress < task.target) {
      claimResult.reason = "not_completed";
      patchUserLiteIfNeeded(reputationBefore, daily.claimedPoints);
      if (shouldWriteDaily) {
        tx.set(
          dailyRef,
          buildDailyWritePayload({
            daily,
            includeCreatedAt: !dailySnap.exists,
          }),
          { merge: true }
        );
      }
      return;
    }

    const remainingDaily = Math.max(0, daily.cap - daily.claimedPoints);
    const remainingScore = Math.max(0, REPUTATION_MAX_SCORE - reputationBefore);
    const awarded = Math.max(
      0,
      Math.min(task.reward, remainingDaily, remainingScore)
    );
    const nextReputation = clamp(
      reputationBefore + awarded,
      0,
      REPUTATION_MAX_SCORE
    );
    const nextTodayClaimed = daily.claimedPoints + awarded;

    let reason = "claimed";
    if (remainingScore <= 0) {
      reason = "reputation_max_reached";
    } else if (remainingDaily <= 0) {
      reason = "daily_cap_reached";
    }

    daily = {
      ...daily,
      claimedPoints: nextTodayClaimed,
      tasks: {
        ...daily.tasks,
        [taskId]: {
          ...task,
          claimed: true,
          claimedReward: awarded,
          claimedAt: new Date(),
        },
      },
    };
    shouldWriteDaily = true;

    tx.set(
      dailyRef,
      buildDailyWritePayload({
        daily,
        includeCreatedAt: !dailySnap.exists,
        claimTimestampTaskId: taskId,
      }),
      { merge: true }
    );

    tx.set(
      userRef,
      {
        reputationScore: nextReputation,
        reputation: nextReputation,
        reputationTodayDateKey: dateKey,
        reputationTodayClaimed: nextTodayClaimed,
        reputationTodayCap: daily.cap,
        reputationLastClaimAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(claimLogRef, {
      claimId,
      taskId,
      requested: task.reward,
      awarded,
      reputationBefore,
      reputationAfter: nextReputation,
      todayClaimedBefore: claimResult.todayClaimedBefore,
      todayClaimedAfter: nextTodayClaimed,
      reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    claimResult = {
      taskId,
      requested: task.reward,
      awarded,
      reason,
      reputationBefore,
      reputationAfter: nextReputation,
      todayClaimedBefore: claimResult.todayClaimedBefore,
      todayClaimedAfter: nextTodayClaimed,
    };
  });

  const state = await readReputationDailyState({ uid, dateKey, timezone });
  return {
    claim: claimResult,
    state,
  };
});

module.exports = {
  touchReputationDailyOnAppOpen,
  getReputationDailyState,
  claimReputationTask,
};
