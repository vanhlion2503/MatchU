const {
  REPUTATION_DAILY_CAP,
  REPUTATION_MAX_SCORE,
  REPUTATION_DAILY_TASK_CONFIG,
  buildDefaultTasksState,
} = require("./taskConfig");

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function toInt(value, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.trunc(parsed);
    }
  }
  return fallback;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function toBool(value, fallback = false) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true" || normalized === "1") return true;
    if (normalized === "false" || normalized === "0") return false;
  }
  return fallback;
}

function toMillis(value) {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.getTime();
  }
  if (typeof value?.toDate === "function") {
    const converted = value.toDate();
    if (converted instanceof Date && !Number.isNaN(converted.getTime())) {
      return converted.getTime();
    }
  }
  return null;
}

function getCurrentReputationScore(userData) {
  const candidates = [];
  if (typeof userData?.reputationScore === "number") {
    candidates.push(userData.reputationScore);
  }
  if (typeof userData?.reputation === "number") {
    candidates.push(userData.reputation);
  }

  if (candidates.length === 0) return REPUTATION_MAX_SCORE;

  const score = Math.trunc(Math.min(...candidates));
  return clamp(score, 0, REPUTATION_MAX_SCORE);
}

function resolveTaskProgressCap(taskConfig, target) {
  const safeTarget = Math.max(1, toInt(target, 1));
  const isRepeatable =
    taskConfig?.repeatable === true || taskConfig?.claimMode === "auto";
  if (!isRepeatable) return safeTarget;

  const configuredCap = Math.max(
    safeTarget,
    toInt(taskConfig?.dailyProgressCap, safeTarget)
  );
  return configuredCap;
}

function normalizeTaskState(taskId, rawTask) {
  const config = REPUTATION_DAILY_TASK_CONFIG[taskId];
  if (!config) return null;

  const safeTask = isPlainObject(rawTask) ? rawTask : {};
  const isRepeatable = config.repeatable === true || config.claimMode === "auto";
  const target = Math.max(1, toInt(safeTask.target, config.target));
  const progressCap = resolveTaskProgressCap(config, target);
  const reward = Math.max(0, toInt(safeTask.reward, config.reward));
  const progress = clamp(toInt(safeTask.progress, 0), 0, progressCap);
  const claimed = isRepeatable ? false : toBool(safeTask.claimed, false);
  const claimedReward = isRepeatable
    ? Math.max(0, toInt(safeTask.claimedReward, 0))
    : claimed
      ? Math.max(0, toInt(safeTask.claimedReward, reward))
      : 0;
  const claimedAtMs = toMillis(safeTask.claimedAt);

  return {
    target,
    progress,
    reward,
    claimed,
    claimedReward,
    claimedAt: claimedAtMs ? new Date(claimedAtMs) : null,
  };
}

function normalizeTasks(rawTasks) {
  const safeRawTasks = isPlainObject(rawTasks) ? rawTasks : {};
  const defaults = buildDefaultTasksState();
  const normalized = {};

  for (const taskId of Object.keys(defaults)) {
    normalized[taskId] = normalizeTaskState(taskId, safeRawTasks[taskId]);
  }

  return normalized;
}

function normalizeRuntime(rawRuntime) {
  const safeRuntime = isPlainObject(rawRuntime) ? rawRuntime : {};
  const onlineSessionStartMsRaw = safeRuntime.onlineSessionStartMs;
  const onlineSessionStartMs =
    typeof onlineSessionStartMsRaw === "number" &&
    Number.isFinite(onlineSessionStartMsRaw)
      ? Math.trunc(onlineSessionStartMsRaw)
      : null;
  const usageCarryMs = Math.max(0, toInt(safeRuntime.usageCarryMs, 0));

  return {
    onlineSessionStartMs,
    usageCarryMs,
  };
}

function normalizeDailyDoc(rawDaily, { dateKey, timezone }) {
  const safeRawDaily = isPlainObject(rawDaily) ? rawDaily : {};
  const cap = Math.max(1, toInt(safeRawDaily.cap, REPUTATION_DAILY_CAP));
  const claimedPoints = Math.max(0, toInt(safeRawDaily.claimedPoints, 0));
  const tasks = normalizeTasks(safeRawDaily.tasks);
  const runtime = normalizeRuntime(safeRawDaily.runtime);

  return {
    dateKey,
    timezone,
    cap,
    claimedPoints,
    tasks,
    runtime,
    createdAt: safeRawDaily.createdAt || null,
    updatedAt: safeRawDaily.updatedAt || null,
  };
}

function taskStateToClient(taskState) {
  return {
    target: taskState.target,
    progress: taskState.progress,
    reward: taskState.reward,
    claimed: taskState.claimed,
    claimedReward: taskState.claimedReward,
    isCompleted: taskState.progress >= taskState.target,
    claimedAtMillis: taskState.claimedAt ? taskState.claimedAt.getTime() : null,
  };
}

function buildDailyStatePayload({ reputationScore, daily }) {
  const tasks = {};
  for (const [taskId, taskState] of Object.entries(daily.tasks)) {
    tasks[taskId] = taskStateToClient(taskState);
  }

  return {
    dateKey: daily.dateKey,
    timezone: daily.timezone,
    dailyCap: daily.cap,
    todayClaimed: daily.claimedPoints,
    reputationScore,
    reputationMax: REPUTATION_MAX_SCORE,
    canEarnMore:
      reputationScore < REPUTATION_MAX_SCORE && daily.claimedPoints < daily.cap,
    tasks,
  };
}

module.exports = {
  isPlainObject,
  toInt,
  clamp,
  toBool,
  toMillis,
  getCurrentReputationScore,
  normalizeTaskState,
  normalizeTasks,
  normalizeRuntime,
  normalizeDailyDoc,
  buildDailyStatePayload,
  resolveTaskProgressCap,
};
