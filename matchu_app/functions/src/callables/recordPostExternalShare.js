const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { admin, db } = require("../shared/firebase");

const ALLOWED_METHODS = new Set(["native", "copy"]);
const MAX_SHARES_PER_USER_PER_DAY = 200;
const MAX_SHARES_PER_POST_PER_DAY = 20;

function normalizeIdentifier(value, maxLength = 200) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized || normalized.length > maxLength) return "";
  return /^[A-Za-z0-9_-]+$/.test(normalized) ? normalized : "";
}

function normalizeEventId(value) {
  const normalized = typeof value === "string" ? value.trim() : "";
  return /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(normalized)
    ? normalized
    : "";
}

function utcDayKey(date = new Date()) {
  return date.toISOString().slice(0, 10).replaceAll("-", "");
}

function externalShareCountOf(post) {
  const value = Number(post?.stats?.externalShareCount) || 0;
  return Math.max(0, Math.trunc(value));
}

function isExternallyShareable(post) {
  const visibility = typeof post?.visibility === "string"
    ? post.visibility
    : post?.isPublic === true
      ? "public"
      : "private";
  const moderationStatus = typeof post?.moderationStatus === "string"
    ? post.moderationStatus
    : "approved";
  return Boolean(
    post &&
    !post.deletedAt &&
    visibility === "public" &&
    moderationStatus === "approved"
  );
}

const recordPostExternalShare = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const uid = normalizeIdentifier(request.auth.uid, 128);
    const postId = normalizeIdentifier(request.data?.postId);
    const eventId = normalizeEventId(request.data?.eventId);
    const method = typeof request.data?.method === "string"
      ? request.data.method.trim().toLowerCase()
      : "";
    if (!uid || !postId || !eventId || !ALLOWED_METHODS.has(method)) {
      throw new HttpsError("invalid-argument", "Invalid share event.");
    }

    const dayKey = utcDayKey();
    const postRef = db.collection("posts").doc(postId);
    const eventRef = db.collection("postShareEvents").doc(`${uid}_${eventId}`);
    const rateCollection = db.collection("users").doc(uid)
      .collection("postShareRateLimits");
    const userRateRef = rateCollection.doc(dayKey);
    const postRateRef = rateCollection.doc(`${dayKey}_${postId}`);

    return db.runTransaction(async (transaction) => {
      const [postSnap, eventSnap, userRateSnap, postRateSnap] =
        await Promise.all([
          transaction.get(postRef),
          transaction.get(eventRef),
          transaction.get(userRateRef),
          transaction.get(postRateRef),
        ]);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "Post not found.");
      }
      const post = postSnap.data() || {};
      const currentCount = externalShareCountOf(post);
      if (eventSnap.exists) {
        return { externalShareCount: currentCount, counted: false };
      }
      if (!isExternallyShareable(post)) {
        throw new HttpsError(
          "failed-precondition",
          "Post is not available for external sharing."
        );
      }

      const userDailyCount = Number(userRateSnap.data()?.count) || 0;
      const postDailyCount = Number(postRateSnap.data()?.count) || 0;
      if (userDailyCount >= MAX_SHARES_PER_USER_PER_DAY ||
          postDailyCount >= MAX_SHARES_PER_POST_PER_DAY) {
        throw new HttpsError("resource-exhausted", "Share limit reached.");
      }

      const nextCount = currentCount + 1;
      const now = admin.firestore.FieldValue.serverTimestamp();
      transaction.update(postRef, {
        "stats.externalShareCount": nextCount,
        updatedAt: now,
      });
      transaction.create(eventRef, {
        eventId,
        postId,
        userId: uid,
        method,
        createdAt: now,
      });
      transaction.set(userRateRef, {
        dayKey,
        count: userDailyCount + 1,
        updatedAt: now,
      }, { merge: true });
      transaction.set(postRateRef, {
        dayKey,
        postId,
        count: postDailyCount + 1,
        updatedAt: now,
      }, { merge: true });

      return { externalShareCount: nextCount, counted: true };
    });
  }
);

module.exports = {
  recordPostExternalShare,
  _test: {
    externalShareCountOf,
    isExternallyShareable,
    normalizeEventId,
    normalizeIdentifier,
    utcDayKey,
  },
};
