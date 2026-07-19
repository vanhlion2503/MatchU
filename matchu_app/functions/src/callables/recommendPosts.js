const { onCall, HttpsError } = require("firebase-functions/v2/https");
const crypto = require("node:crypto");
const { admin, db } = require("../shared/firebase");

const {
  getOrBuildRecommendationPool,
  isRecommendationSessionReusable,
  recommendationCacheRef,
  recommendationFeedStateRef,
  toSafeUid,
} = require("../recommendation/core");

const MAX_LIMIT = 50;
const SESSION_TTL_MS = 30 * 60 * 1000;

function safeSessionId(value) {
  const normalized = typeof value === "string" ? value.trim() : "";
  return /^[A-Za-z0-9_-]{8,100}$/.test(normalized) ? normalized : "";
}

function safePostIds(value, limit = 100) {
  if (!Array.isArray(value)) return [];
  return Array.from(new Set(value
    .map((postId) => typeof postId === "string" ? postId.trim() : "")
    .filter((postId) => postId && postId.length <= 160)))
    .slice(0, limit);
}

function sessionRef(uid, sessionId) {
  return db.collection("users").doc(uid).collection("feedSessions").doc(sessionId);
}

const recommendPosts = onCall(
  { timeoutSeconds: 60, memory: "1GiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const uid = toSafeUid(request.auth.uid);
    const limit = Math.min(Math.max(Number(request.data?.limit) || 20, 1), MAX_LIMIT);
    let page = Math.max(Number(request.data?.page) || 1, 1);
    const forceRefresh = request.data?.forceRefresh === true;
    const requestedSessionId = safeSessionId(request.data?.sessionId);
    const previousSessionId = safeSessionId(request.data?.previousSessionId);
    const excludedPostIds = new Set(
      safePostIds(request.data?.excludedPostIds),
    );

    try {
      const nowMillis = Date.now();
      if (forceRefresh && previousSessionId) {
        const previousSessionSnap = await sessionRef(uid, previousSessionId).get();
        if (previousSessionSnap.exists) {
          for (const postId of safePostIds(
            previousSessionSnap.data()?.servedPostIds,
            140,
          )) {
            excludedPostIds.add(postId);
          }
        }
      }
      let sessionId = forceRefresh ? "" : requestedSessionId;
      let session = null;
      if (sessionId) {
        const [sessionSnap, cacheSnap, feedStateSnap] = await Promise.all([
          sessionRef(uid, sessionId).get(),
          recommendationCacheRef(uid).get(),
          recommendationFeedStateRef().get(),
        ]);
        const data = sessionSnap.data();
        const invalidatedAtMillis =
          cacheSnap.data()?.invalidatedAt?.toMillis?.() || 0;
        const currentFeedRevision =
          Number(feedStateSnap.data()?.revision) || 0;
        if (sessionSnap.exists && isRecommendationSessionReusable(
          data,
          nowMillis,
          invalidatedAtMillis,
          currentFeedRevision,
        )) {
          session = data;
        } else {
          sessionId = "";
        }
      }

      if (!session) {
        // A missing, expired, or invalidated session represents a new ordered
        // pool. Always serve its first page instead of applying an offset that
        // belonged to the previous session.
        page = 1;
        sessionId = crypto.randomUUID();
        const seed = `${uid}:${sessionId}`;
        const pool = await getOrBuildRecommendationPool(uid, {
          forceRefresh,
          seed,
          excludedPostIds: Array.from(excludedPostIds).slice(0, 200),
        });
        session = {
          postIds: pool.postIds,
          scoresByPostId: pool.scoresByPostId || {},
          metadata: pool.metadata || {},
          poolId: crypto.randomUUID(),
          feedRevision: Number(pool.metadata?.feedRevision) || 0,
          createdAtMillis: nowMillis,
          expiresAtMillis: nowMillis + SESSION_TTL_MS,
        };
        await sessionRef(uid, sessionId).set({
          ...session,
          sessionId,
          servedPostIds: [],
          algorithmVersion: session.metadata.algorithmVersion || "unknown",
          previousSessionId: previousSessionId || null,
          refreshExcludedPostCount: excludedPostIds.size,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(session.expiresAtMillis),
        });
      }

      const offset = (page - 1) * limit;
      const selectedPostIds = session.postIds.slice(offset, offset + limit);
      if (selectedPostIds.length) {
        await sessionRef(uid, sessionId).set({
          servedPostIds: admin.firestore.FieldValue.arrayUnion(...selectedPostIds),
          lastServedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      return {
        postIds: selectedPostIds,
        limit,
        page,
        hasMore: offset + limit < session.postIds.length,
        scoresByPostId: session.scoresByPostId || {},
        sessionId,
        poolId: session.poolId,
        metadata: {
          ...(session.metadata || {}),
          sessionReused: Boolean(requestedSessionId && requestedSessionId === sessionId),
          requestError: null,
          totalRecommended: selectedPostIds.length,
          pagePoolSize: session.postIds.length,
          refreshExcludedPostCount:
            Number(session.refreshExcludedPostCount) || excludedPostIds.size,
        },
        generatedAt: new Date().toISOString(),
      };
    } catch (error) {
      console.error("recommendPosts failed:", {
        uid,
        error: error?.message || String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Unable to generate recommendations.");
    }
  }
);

module.exports = {
  recommendPosts,
};
