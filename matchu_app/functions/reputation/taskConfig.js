const DEFAULT_REPUTATION_TIMEZONE = "Asia/Ho_Chi_Minh";
const REPUTATION_DAILY_CAP = 10;
const REPUTATION_MAX_SCORE = 100;
const APP_USAGE_REWARD_INTERVAL_MINUTES = 15;
const TEMP_CHAT_DAILY_TARGET_ROOMS = 3;

const REPUTATION_DAILY_TASK_CONFIG = Object.freeze({
  loginDaily: Object.freeze({
    target: 1,
    reward: 1,
    claimMode: "manual",
    repeatable: false,
  }),
  appUsage15Minutes: Object.freeze({
    target: APP_USAGE_REWARD_INTERVAL_MINUTES,
    reward: 1,
    claimMode: "manual",
    repeatable: false,
  }),
  tempChat3Rooms3Minutes: Object.freeze({
    target: TEMP_CHAT_DAILY_TARGET_ROOMS,
    reward: 2,
    claimMode: "manual",
    repeatable: false,
  }),
});

function getTaskConfig(taskId) {
  if (typeof taskId !== "string") return null;
  return REPUTATION_DAILY_TASK_CONFIG[taskId] || null;
}

function buildDefaultTaskState(taskId) {
  const config = getTaskConfig(taskId);
  if (!config) return null;

  return {
    target: config.target,
    progress: 0,
    reward: config.reward,
    claimed: false,
    claimedReward: 0,
    claimedAt: null,
  };
}

function buildDefaultTasksState() {
  const tasks = {};
  for (const taskId of Object.keys(REPUTATION_DAILY_TASK_CONFIG)) {
    tasks[taskId] = buildDefaultTaskState(taskId);
  }
  return tasks;
}

module.exports = {
  DEFAULT_REPUTATION_TIMEZONE,
  REPUTATION_DAILY_CAP,
  REPUTATION_MAX_SCORE,
  APP_USAGE_REWARD_INTERVAL_MINUTES,
  TEMP_CHAT_DAILY_TARGET_ROOMS,
  REPUTATION_DAILY_TASK_CONFIG,
  getTaskConfig,
  buildDefaultTaskState,
  buildDefaultTasksState,
};
