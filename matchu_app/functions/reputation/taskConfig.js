const DEFAULT_REPUTATION_TIMEZONE = "Asia/Ho_Chi_Minh";
const REPUTATION_DAILY_CAP = 10;
const REPUTATION_MAX_SCORE = 100;

const REPUTATION_DAILY_TASK_CONFIG = Object.freeze({
  loginDaily: Object.freeze({
    target: 1,
    reward: 1,
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
  REPUTATION_DAILY_TASK_CONFIG,
  getTaskConfig,
  buildDefaultTaskState,
  buildDefaultTasksState,
};
