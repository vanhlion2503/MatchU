const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../src/shared/firebase");
const {
  normalizeTimezone,
  resolveDateKey,
} = require("../utils/dateKey");
const {
  DEFAULT_REPUTATION_TIMEZONE,
  REPUTATION_MAX_SCORE,
  APP_USAGE_REWARD_INTERVAL_MINUTES,
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
const APP_USAGE_TASK_ID = "appUsage15Minutes";
const MINUTE_MS = 60 * 1000;
const APP_USAGE_REWARD_INTERVAL_MS =
  APP_USAGE_REWARD_INTERVAL_MINUTES * MINUTE_MS;
const MAX_SESSION_ELAPSED_MS = 5 * MINUTE_MS;
const SESSION_END_SOURCES = new Set([
  "pause",
  "inactive",
  "hidden",
  "detached",
  "logout",
]);

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

function sanitizeSource(rawValue) {
  const source =
    typeof rawValue === "string" ? rawValue.trim().toLowerCase() : "";
  if (!source) return "app_open";
  return source.slice(0, 32);
}

function shouldKeepSessionActive(source) {
  return !SESSION_END_SOURCES.has(source);
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
  const rawUsageCarryMs = Math.max(0, toInt(rawRuntime.usageCarryMs, 0));
  if (rawUsageCarryMs !== normalizedDaily.runtime.usageCarryMs) {
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
  const hasOwn = (key) =>
    userData && Object.prototype.hasOwnProperty.call(userData, key);
  const patch = {};

  const currentReputationScore = toInt(userData?.reputationScore, reputationScore);
  if (!hasOwn("reputationScore") || currentReputationScore !== reputationScore) {
    patch.reputationScore = reputationScore;
  }

  const currentReputation = toInt(userData?.reputation, reputationScore);
  if (!hasOwn("reputation") || currentReputation !== reputationScore) {
    patch.reputation = reputationScore;
  }

  const currentDateKey =
    typeof userData?.reputationTodayDateKey === "string"
      ? userData.reputationTodayDateKey
      : null;
  if (!hasOwn("reputationTodayDateKey") || currentDateKey !== dateKey) {
    patch.reputationTodayDateKey = dateKey;
  }

  const currentClaimed = Math.max(
    0,
    toInt(userData?.reputationTodayClaimed, 0)
  );
  if (!hasOwn("reputationTodayClaimed") || currentClaimed !== todayClaimed) {
    patch.reputationTodayClaimed = todayClaimed;
  }

  const currentCap = Math.max(1, toInt(userData?.reputationTodayCap, 10));
  if (!hasOwn("reputationTodayCap") || currentCap !== cap) {
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
  const source = sanitizeSource(payload.source);
  const keepSessionActive = shouldKeepSessionActive(source);

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
        source,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const reputationScore = getCurrentReputationScore(userData);
    const usageTask = daily.tasks[APP_USAGE_TASK_ID];
    const nowMs = Date.now();
    const previousOnlineSessionStartMs =
      typeof daily.runtime.onlineSessionStartMs === "number" &&
      Number.isFinite(daily.runtime.onlineSessionStartMs)
        ? Math.trunc(daily.runtime.onlineSessionStartMs)
        : null;
    let elapsedMs = 0;
    if (previousOnlineSessionStartMs != null) {
      elapsedMs = Math.max(0, nowMs - previousOnlineSessionStartMs);
      elapsedMs = Math.min(elapsedMs, MAX_SESSION_ELAPSED_MS);
    }

    let usageCarryMs = Math.max(0, toInt(daily.runtime.usageCarryMs, 0));
    if (usageTask && !usageTask.claimed) {
      usageCarryMs = Math.min(
        APP_USAGE_REWARD_INTERVAL_MS,
        usageCarryMs + elapsedMs
      );
    } else {
      usageCarryMs = Math.min(APP_USAGE_REWARD_INTERVAL_MS, usageCarryMs);
    }

    const nextOnlineSessionStartMs = keepSessionActive ? nowMs : null;
    const shouldPatchRuntime =
      daily.runtime.onlineSessionStartMs !== nextOnlineSessionStartMs ||
      daily.runtime.usageCarryMs !== usageCarryMs;

    let shouldPatchUsageTask = false;
    let nextUsageTask = usageTask;
    if (usageTask) {
      const nextProgressMinutes = clamp(
        Math.floor(usageCarryMs / MINUTE_MS),
        0,
        usageTask.target
      );
      shouldPatchUsageTask = usageTask.progress !== nextProgressMinutes;

      if (shouldPatchUsageTask) {
        nextUsageTask = {
          ...usageTask,
          progress: nextProgressMinutes,
        };
      }
    }

    if (shouldPatchRuntime || shouldPatchUsageTask) {
      daily = {
        ...daily,
        runtime: {
          ...daily.runtime,
          onlineSessionStartMs: nextOnlineSessionStartMs,
          usageCarryMs,
        },
        tasks:
          usageTask && nextUsageTask
            ? {
              ...daily.tasks,
              [APP_USAGE_TASK_ID]: nextUsageTask,
            }
            : daily.tasks,
      };
      shouldWriteDaily = true;
    }

    const userPatch = buildUserLitePatchIfNeeded({
      userData,
      reputationScore,
      dateKey,
      todayClaimed: daily.claimedPoints,
      cap: daily.cap,
    });

    if (userPatch && Object.keys(userPatch).length > 0) {
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

const claimReputationTask = onCall(
  {
    // Keep one warm instance to avoid transient 429/resource_exhausted
    // when user taps claim during cold start.
    // minInstances: 1,
  },
  async (request) => {
  const uid = assertAuthenticated(request);
  const payload = parsePayload(request.data);

  const taskId = sanitizeTaskId(payload.taskId);
  const taskConfig = taskId ? getTaskConfig(taskId) : null;
  if (!taskId || !taskConfig) {
    throw new HttpsError("invalid-argument", "Invalid taskId.");
  }
  if (taskConfig.claimMode === "auto") {
    throw new HttpsError(
      "failed-precondition",
      "This task is rewarded automatically."
    );
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
  }
);

module.exports = {
  touchReputationDailyOnAppOpen,
  getReputationDailyState,
  claimReputationTask,
};
