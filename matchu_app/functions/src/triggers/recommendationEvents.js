const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");
const {
  deactivateRecommendationInteraction,
  ensurePostEmbedding,
  invalidateRecommendationCache,
  isEligiblePost,
  isPostEmbeddingCurrent,
  rebuildUserInterestVector,
  recordRecommendationInteraction,
  toSafeUid,
} = require("../recommendation/core");
const {
  syncRecommendationIndexMetadata,
} = require("../recommendation/retrieval");
const {
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
} = require("../recommendation/embedding");
const REBUILD_BATCH_SIZE = 80;
const REBUILD_STALE_DAYS = 3;
const EMBEDDING_BACKFILL_BATCH_SIZE = 80;
const EMBEDDING_BACKFILL_GENERATION =
  `vector_index_v1:${EMBEDDING_MODEL}:${EMBEDDING_DIMENSIONS}`;

function cleanId(value) {
  return typeof value === "string" ? value.trim() : "";
}

function eventVersionMillis(event) {
  const parsed = Date.parse(event?.time || "");
  return Number.isFinite(parsed) ? parsed : Date.now();
}

function postContentSignature(data) {
  const content = typeof data?.content === "string" ? data.content.trim() : "";
  const tags = Array.isArray(data?.tags)
    ? data.tags.filter((tag) => typeof tag === "string").map((tag) => tag.trim())
    : [];
  return JSON.stringify({ content, tags });
}

function postRecommendationMetadataSignature(data) {
  const stats = data?.stats || {};
  const createdAtMillis = typeof data?.createdAt?.toMillis === "function"
    ? data.createdAt.toMillis()
    : 0;
  return JSON.stringify({
    authorId: cleanId(data?.authorId),
    referenceAuthorId: cleanId(data?.referencePost?.authorId),
    visibility: data?.visibility || "",
    moderationStatus: data?.moderationStatus || "approved",
    postType: data?.postType || "post",
    deleted: Boolean(data?.deletedAt),
    createdAtMillis,
    likeCount: Number(stats.likeCount) || 0,
    commentCount: Number(stats.commentCount) || 0,
    shareCount: Number(stats.shareCount) || 0,
    trendScore: Number(data?.trendScore) || 0,
    trendBucket: Number(data?.trendBucket) || 0,
  });
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
    if (!postId) return;
    if (!afterSnap?.exists) {
      await syncRecommendationIndexMetadata(postId, {}, false, {
        eventVersionMillis: eventVersionMillis(event),
      });
      return;
    }

    const before = event.data?.before?.exists ? event.data.before.data() || {} : {};
    const after = afterSnap.data() || {};
    const eligible = isEligiblePost(after);
    const metadataChanged = !event.data?.before?.exists ||
      postRecommendationMetadataSignature(before) !==
        postRecommendationMetadataSignature(after);
    if (metadataChanged) {
      await syncRecommendationIndexMetadata(postId, after, eligible, {
        eventVersionMillis: eventVersionMillis(event),
      });
    }
    if (!eligible) {
      if (after.contentVectorSearchKey != null) {
        await afterSnap.ref.set({
          contentVectorSearchKey: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return;
    }

    const beforeSignature = postContentSignature(before);
    const afterSignature = postContentSignature(after);
    if (
      beforeSignature === afterSignature &&
      isPostEmbeddingCurrent(after)
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
      eventVersionMillis: eventVersionMillis(event),
    });
  }
);

const removeInterestOnPostUnlike = onDocumentDeleted(
  {
    document: "posts/{postId}/likes/{userId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const uid = toSafeUid(event.data?.data()?.userId) || toSafeUid(event.params.userId);
    if (!postId || !uid) return;
    await deactivateRecommendationInteraction({
      uid,
      postId,
      action: "like",
      eventId: `like_${postId}_${uid}`,
      eventVersionMillis: eventVersionMillis(event),
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
      eventVersionMillis: eventVersionMillis(event),
    });
  }
);

const removeInterestOnPostCommentDelete = onDocumentDeleted(
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
    await deactivateRecommendationInteraction({
      uid,
      postId,
      action: "comment",
      eventId: `comment_${postId}_${commentId}`,
      eventVersionMillis: eventVersionMillis(event),
    });
  }
);

const updateInterestOnPostSave = onDocumentCreated(
  {
    document: "users/{userId}/savedPosts/{postId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const uid = toSafeUid(event.params.userId);
    const postId = cleanId(event.params.postId);
    if (!uid || !postId) return;
    await recordRecommendationInteraction({
      uid,
      postId,
      action: "save",
      eventId: `save_${postId}_${uid}`,
      occurredAt: event.data?.data()?.savedAt || admin.firestore.FieldValue.serverTimestamp(),
      eventVersionMillis: eventVersionMillis(event),
    });
  }
);

const removeInterestOnPostUnsave = onDocumentDeleted(
  {
    document: "users/{userId}/savedPosts/{postId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const uid = toSafeUid(event.params.userId);
    const postId = cleanId(event.params.postId);
    if (!uid || !postId) return;
    await deactivateRecommendationInteraction({
      uid,
      postId,
      action: "save",
      eventId: `save_${postId}_${uid}`,
      eventVersionMillis: eventVersionMillis(event),
    });
  }
);

const updateInterestOnQuoteOrRepost = onDocumentWritten(
  {
    document: "posts/{postId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const before = event.data?.before?.exists ? event.data.before.data() || {} : {};
    const after = event.data?.after?.exists ? event.data.after.data() || {} : {};
    const post = event.data?.after?.exists ? after : before;
    const uid = toSafeUid(post.authorId);
    const postType = typeof post.postType === "string" ? post.postType : "";
    const referencePostId =
      typeof post.referencePostId === "string" ? post.referencePostId.trim() : "";

    if (!postId || !uid || !referencePostId) return;
    if (postType !== "quote" && postType !== "repost") return;

    const wasActive = event.data?.before?.exists &&
      !before.deletedAt &&
      (before.postType === "quote" || before.postType === "repost");
    const isActive = event.data?.after?.exists &&
      !after.deletedAt &&
      (after.postType === "quote" || after.postType === "repost");
    if (wasActive === isActive) return;

    const interaction = {
      uid,
      postId: referencePostId,
      action: "share",
      eventId: `${postType}_${postId}_${referencePostId}`,
      eventVersionMillis: eventVersionMillis(event),
    };
    if (isActive) {
      await recordRecommendationInteraction({
        ...interaction,
        occurredAt: post.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await deactivateRecommendationInteraction(interaction);
    }
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
    schedule: "every 15 minutes",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async () => {
    const stateRef = db
      .collection("system")
      .doc("recommendationVectorBackfill");
    const stateSnap = await stateRef.get();
    const state = stateSnap.data() || {};
    const generationMatches =
      state.generation === EMBEDDING_BACKFILL_GENERATION;
    if (generationMatches && state.completed === true) {
      console.info("recommendation vector backfill already completed:", {
        generation: EMBEDDING_BACKFILL_GENERATION,
      });
      return;
    }

    let query = db
      .collection("posts")
      .where("visibility", "==", "public")
      .where("moderationStatus", "==", "approved")
      .orderBy("createdAt", "desc")
      .orderBy(admin.firestore.FieldPath.documentId(), "desc")
      .limit(EMBEDDING_BACKFILL_BATCH_SIZE);
    if (
      generationMatches &&
      state.cursorCreatedAt &&
      typeof state.cursorPostId === "string" &&
      state.cursorPostId
    ) {
      query = query.startAfter(state.cursorCreatedAt, state.cursorPostId);
    }

    const snapshot = await query.get();

    let embeddedCount = 0;
    let scannedCount = 0;
    let failedPostId = null;
    let lastSuccessfulDoc = null;
    for (const doc of snapshot.docs) {
      const post = doc.data() || {};
      try {
        if (isEligiblePost(post)) {
          await syncRecommendationIndexMetadata(doc.id, post, true, {
            reconcileSource: true,
          });
          if (!isPostEmbeddingCurrent(post)) {
            await ensurePostEmbedding(doc.id, post);
            embeddedCount += 1;
          }
        } else {
          await syncRecommendationIndexMetadata(doc.id, post, false, {
            reconcileSource: true,
          });
        }
        scannedCount += 1;
        lastSuccessfulDoc = doc;
      } catch (error) {
        console.error("backfillRecentPostEmbeddings failed:", {
          postId: doc.id,
          error: error?.message || String(error),
        });
        failedPostId = doc.id;
        break;
      }
    }

    const completed = !failedPostId &&
      snapshot.size < EMBEDDING_BACKFILL_BATCH_SIZE;
    const lastData = lastSuccessfulDoc?.data() || {};
    await stateRef.set({
      generation: EMBEDDING_BACKFILL_GENERATION,
      completed,
      cursorCreatedAt: completed
        ? admin.firestore.FieldValue.delete()
        : (lastData.createdAt ||
          (generationMatches ? state.cursorCreatedAt : null) ||
          null),
      cursorPostId: completed
        ? admin.firestore.FieldValue.delete()
        : (lastSuccessfulDoc?.id ||
          (generationMatches ? state.cursorPostId : null) ||
          null),
      failedPostId,
      scannedCount: generationMatches
        ? admin.firestore.FieldValue.increment(scannedCount)
        : scannedCount,
      embeddedCount: generationMatches
        ? admin.firestore.FieldValue.increment(embeddedCount)
        : embeddedCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: completed
        ? admin.firestore.FieldValue.serverTimestamp()
        : null,
    }, { merge: true });

    console.info("backfillRecentPostEmbeddings completed:", {
      generation: EMBEDDING_BACKFILL_GENERATION,
      scannedCount,
      embeddedCount,
      completed,
      failedPostId,
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

const invalidateRecommendationCacheOnHiddenPost = onDocumentWritten(
  "users/{userId}/hiddenPosts/{postId}",
  async (event) => {
    await invalidateRecommendationCache(event.params.userId, "hidden_post");
  }
);

const invalidateRecommendationCacheOnBlockedBy = onDocumentWritten(
  "users/{userId}/blockedBy/{blockerId}",
  async (event) => {
    await invalidateRecommendationCache(event.params.userId, "blocked_by");
  }
);

module.exports = {
  backfillRecentPostEmbeddings,
  embedPostContent,
  invalidateRecommendationCacheOnBlockedBy,
  invalidateRecommendationCacheOnBlock,
  invalidateRecommendationCacheOnHiddenPost,
  invalidateRecommendationCacheOnRestrictions,
  removeInterestOnPostCommentDelete,
  removeInterestOnPostUnlike,
  removeInterestOnPostUnsave,
  rebuildStaleInterestVectors,
  updateInterestOnPostComment,
  updateInterestOnPostLike,
  updateInterestOnPostSave,
  updateInterestOnQuoteOrRepost,
};
