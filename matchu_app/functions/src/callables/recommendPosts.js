const { onCall, HttpsError } = require("firebase-functions/v2/https");

const {
  getOrBuildRecommendationPool,
  toSafeUid,
} = require("../recommendation/core");

const MAX_LIMIT = 50;

const recommendPosts = onCall(
  { timeoutSeconds: 60, memory: "1GiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const uid = toSafeUid(request.auth.uid);
    const limit = Math.min(Math.max(Number(request.data?.limit) || 20, 1), MAX_LIMIT);
    const page = Math.max(Number(request.data?.page) || 1, 1);
    const forceRefresh = request.data?.forceRefresh === true;

    try {
      const pool = await getOrBuildRecommendationPool(uid, { forceRefresh });
      const offset = (page - 1) * limit;
      const selectedPostIds = pool.postIds.slice(offset, offset + limit);

      return {
        postIds: selectedPostIds,
        limit,
        page,
        hasMore: offset + limit < pool.postIds.length,
        scoresByPostId: pool.scoresByPostId || {},
        metadata: {
          ...(pool.metadata || {}),
          totalRecommended: selectedPostIds.length,
          pagePoolSize: pool.postIds.length,
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
