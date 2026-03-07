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

    const patch = {};

    if (toInt(userData.reputationScore, reputationScore) !== reputationScore) {
      patch.reputationScore = reputationScore;
    }
    if (toInt(userData.reputation, reputationScore) !== reputationScore) {
      patch.reputation = reputationScore;
    }

    if (typeof userData.reputationTodayDateKey !== "string") {
      patch.reputationTodayDateKey = null;
    }

    const todayClaimed = Math.max(0, toInt(userData.reputationTodayClaimed, -1));
    if (todayClaimed < 0) {
      patch.reputationTodayClaimed = 0;
    }

    const todayCap = Math.max(1, toInt(userData.reputationTodayCap, -1));
    if (todayCap < 1) {
      patch.reputationTodayCap = REPUTATION_DAILY_CAP;
    }

    if (!Object.prototype.hasOwnProperty.call(userData, "reputationLastClaimAt")) {
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
