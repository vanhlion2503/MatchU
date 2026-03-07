const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const { admin } = require("../src/shared/firebase");
const {
  REPUTATION_DAILY_CAP,
} = require("./taskConfig");
const {
  toInt,
  getCurrentReputationScore,
} = require("./types");

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
};
