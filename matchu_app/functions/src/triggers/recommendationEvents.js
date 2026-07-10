const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");
const {
  ensurePostEmbedding,
  invalidateRecommendationCache,
  isEligiblePost,
  rebuildUserInterestVector,
  recordRecommendationInteraction,
  toSafeUid,
} = require("../recommendation/core");
const { EMBEDDING_MODEL } = require("../recommendation/embedding");

const REBUILD_BATCH_SIZE = 80;
const REBUILD_STALE_DAYS = 3;
const EMBEDDING_BACKFILL_BATCH_SIZE = 80;

function cleanId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function postContentSignature(data) {
  const content = typeof data?.content === "string" ? data.content.trim() : "";
  const tags = Array.isArray(data?.tags)
    ? data.tags.filter((tag) => typeof tag === "string").map((tag) => tag.trim())
    : [];
  return JSON.stringify({ content, tags });
}

const embedPostContent = onDocumentWritten(
  {
    document: "posts/{postId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const afterSnap = event.data?.after;
    if (!postId || !afterSnap?.exists) return;

    const before = event.data?.before?.exists ? event.data.before.data() || {} : {};
    const after = afterSnap.data() || {};
    if (!isEligiblePost(after)) return;

    const beforeSignature = postContentSignature(before);
    const afterSignature = postContentSignature(after);
    const existingVector = Array.isArray(after.contentVector)
      ? after.contentVector
      : [];
    const modelMatches = after.contentEmbeddingModel === EMBEDDING_MODEL;
    if (
      beforeSignature === afterSignature &&
      existingVector.length > 0 &&
      modelMatches
    ) {
      return;
    }

    try {
      await ensurePostEmbedding(postId, after);
    } catch (error) {
      console.error("embedPostContent failed:", {
        postId,
        error: error?.message || String(error),
      });
    }
  }
);

const updateInterestOnPostLike = onDocumentCreated(
  {
    document: "posts/{postId}/likes/{userId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const uid = toSafeUid(event.data?.data()?.userId) || toSafeUid(event.params.userId);
    if (!postId || !uid) return;

    await recordRecommendationInteraction({
      uid,
      postId,
      action: "like",
      eventId: `like_${postId}_${uid}`,
      occurredAt: event.data?.data()?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

const updateInterestOnPostComment = onDocumentCreated(
  {
    document: "posts/{postId}/comments/{commentId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const commentId = cleanId(event.params.commentId);
    const uid = toSafeUid(event.data?.data()?.userId);
    if (!postId || !commentId || !uid) return;

    await recordRecommendationInteraction({
      uid,
      postId,
      action: "comment",
      eventId: `comment_${postId}_${commentId}`,
      occurredAt: event.data?.data()?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

const updateInterestOnQuoteOrRepost = onDocumentCreated(
  {
    document: "posts/{postId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const post = event.data?.data() || {};
    const uid = toSafeUid(post.authorId);
    const postType = typeof post.postType === "string" ? post.postType : "";
    const referencePostId =
      typeof post.referencePostId === "string" ? post.referencePostId.trim() : "";

    if (!postId || !uid || !referencePostId) return;
    if (postType !== "quote" && postType !== "repost") return;

    await recordRecommendationInteraction({
      uid,
      postId: referencePostId,
      action: "share",
      eventId: `${postType}_${postId}_${referencePostId}`,
      occurredAt: post.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

const rebuildStaleInterestVectors = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - REBUILD_STALE_DAYS * 86400000
    );
    const snapshot = await db
      .collection("users")
      .where("interestUpdatedAt", "<=", cutoff)
      .limit(REBUILD_BATCH_SIZE)
      .get();

    let rebuiltCount = 0;
    for (const doc of snapshot.docs) {
      try {
        const rebuilt = await rebuildUserInterestVector(doc.id);
        if (rebuilt) rebuiltCount += 1;
      } catch (error) {
        console.error("rebuildUserInterestVector failed:", {
          uid: doc.id,
          error: error?.message || String(error),
        });
      }
    }

    console.info("rebuildStaleInterestVectors completed:", {
      scannedCount: snapshot.size,
      rebuiltCount,
    });
  }
);

const backfillRecentPostEmbeddings = onSchedule(
  {
    schedule: "every 12 hours",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async () => {
    const snapshot = await db
      .collection("posts")
      .where("visibility", "==", "public")
      .where("moderationStatus", "==", "approved")
      .orderBy("createdAt", "desc")
      .limit(EMBEDDING_BACKFILL_BATCH_SIZE)
      .get();

    let embeddedCount = 0;
    for (const doc of snapshot.docs) {
      const post = doc.data() || {};
      const hasVector =
        Array.isArray(post.contentVector) && post.contentVector.length > 0;
      const modelMatches = post.contentEmbeddingModel === EMBEDDING_MODEL;
      if (hasVector && modelMatches) continue;

      try {
        await ensurePostEmbedding(doc.id, post);
        embeddedCount += 1;
      } catch (error) {
        console.error("backfillRecentPostEmbeddings failed:", {
          postId: doc.id,
          error: error?.message || String(error),
        });
      }
    }

    console.info("backfillRecentPostEmbeddings completed:", {
      scannedCount: snapshot.size,
      embeddedCount,
    });
  }
);

const invalidateRecommendationCacheOnRestrictions = onDocumentWritten(
  "users/{userId}/hiddenPostAuthors/{authorId}",
  async (event) => {
    await invalidateRecommendationCache(event.params.userId, "hidden_author");
  }
);

const invalidateRecommendationCacheOnBlock = onDocumentWritten(
  "users/{userId}/blockedUsers/{blockedUserId}",
  async (event) => {
    await invalidateRecommendationCache(event.params.userId, "blocked_user");
  }
);

module.exports = {
  backfillRecentPostEmbeddings,
  embedPostContent,
  invalidateRecommendationCacheOnBlock,
  invalidateRecommendationCacheOnRestrictions,
  rebuildStaleInterestVectors,
  updateInterestOnPostComment,
  updateInterestOnPostLike,
  updateInterestOnQuoteOrRepost,
};
