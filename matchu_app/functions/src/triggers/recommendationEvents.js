const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");
const {
  deactivateRecommendationInteraction,
  bumpRecommendationFeedRevision,
  ensurePostEmbedding,
  invalidateRecommendationCache,
  isEligiblePost,
  isPostEmbeddingCurrent,
  rebuildUserInterestVector,
  recordRecommendationInteraction,
  recordNegativeRecommendationInteraction,
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
const EMBEDDING_RETRY_BATCH_SIZE = 20;
// ONNX plus the Cloud Run Node runtime peaks above 2 GiB during cold starts,
// even with q4 weights. Leave headroom and allow one inference per instance.
const EMBEDDING_RUNTIME_OPTIONS = Object.freeze({
  memory: "4GiB",
  concurrency: 1,
  maxInstances: 2,
});
const EMBEDDING_BACKFILL_GENERATION =
  `vector_index_v2_search_v2:${EMBEDDING_MODEL}:${EMBEDDING_DIMENSIONS}`;

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
    externalShareCount: Number(stats.externalShareCount) || 0,
    saveCount: Number(stats.saveCount) || 0,
    trendScore: Number(data?.trendScore) || 0,
    trendBucket: Number(data?.trendBucket) || 0,
  });
}

function postRecommendationPoolSignature(data) {
  return JSON.stringify({
    content: postContentSignature(data),
    authorId: cleanId(data?.authorId),
    referenceAuthorId: cleanId(data?.referencePost?.authorId),
    visibility: data?.visibility || "",
    moderationStatus: data?.moderationStatus || "approved",
    postType: data?.postType || "post",
    deleted: Boolean(data?.deletedAt),
  });
}

function recommendationErrorCode(error) {
  const rawCode = error?.code || error?.name || "embedding_failed";
  return String(rawCode)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, "_")
    .slice(0, 80) || "embedding_failed";
}

async function markRecommendationFailure(postRef, error) {
  await postRef.set({
    recommendationStatus: "failed",
    recommendationErrorCode: recommendationErrorCode(error),
    recommendationAttemptCount: admin.firestore.FieldValue.increment(1),
    recommendationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

const embedPostContent = onDocumentWritten(
  {
    document: "posts/{postId}",
    timeoutSeconds: 120,
    ...EMBEDDING_RUNTIME_OPTIONS,
  },
  async (event) => {
    const postId = cleanId(event.params.postId);
    const afterSnap = event.data?.after;
    if (!postId) return;
    if (!afterSnap?.exists) {
      await syncRecommendationIndexMetadata(postId, {}, false, {
        eventVersionMillis: eventVersionMillis(event),
      });
      await bumpRecommendationFeedRevision("post_deleted");
      return;
    }

    const before = event.data?.before?.exists ? event.data.before.data() || {} : {};
    const after = afterSnap.data() || {};
    const eligible = isEligiblePost(after);
    const metadataChanged = !event.data?.before?.exists ||
      postRecommendationMetadataSignature(before) !==
        postRecommendationMetadataSignature(after);
    const poolChanged = !event.data?.before?.exists ||
      postRecommendationPoolSignature(before) !==
        postRecommendationPoolSignature(after);
    if (metadataChanged) {
      await syncRecommendationIndexMetadata(postId, after, eligible, {
        eventVersionMillis: eventVersionMillis(event),
      });
    }
    if (poolChanged && (isEligiblePost(before) || eligible)) {
      await bumpRecommendationFeedRevision(
        event.data?.before?.exists ? "post_changed" : "post_created"
      );
    }
    if (!eligible) {
      if (
        after.contentVectorSearchKey != null ||
        after.recommendationStatus !== "ineligible"
      ) {
        await afterSnap.ref.set({
          contentVectorSearchKey: null,
          recommendationStatus: "ineligible",
          recommendationErrorCode: admin.firestore.FieldValue.delete(),
          recommendationAttemptCount: admin.firestore.FieldValue.increment(0),
          recommendationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return;
    }

    const beforeSignature = postContentSignature(before);
    const afterSignature = postContentSignature(after);
    // A failure write must not recursively invoke the expensive model again.
    // Content edits and the scheduled retry job still get another attempt.
    if (
      after.recommendationStatus === "failed" &&
      beforeSignature === afterSignature
    ) {
      return;
    }
    if (
      beforeSignature === afterSignature &&
      isPostEmbeddingCurrent(after)
    ) {
      return;
    }

    try {
      await ensurePostEmbedding(postId, after);
    } catch (error) {
      await markRecommendationFailure(afterSnap.ref, error);
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
    ...EMBEDDING_RUNTIME_OPTIONS,
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
    ...EMBEDDING_RUNTIME_OPTIONS,
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
    ...EMBEDDING_RUNTIME_OPTIONS,
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

const updateInterestOnDwell = onDocumentWritten(
  {
    document: "users/{userId}/feedImpressions/{postId}",
    timeoutSeconds: 120,
    ...EMBEDDING_RUNTIME_OPTIONS,
  },
  async (event) => {
    const beforeMs = Number(event.data?.before?.data()?.totalDwellMs) || 0;
    const after = event.data?.after?.data() || {};
    const afterMs = Number(after.totalDwellMs) || 0;
    // One lightweight learning event per post after meaningful attention.
    if (beforeMs >= 3000 || afterMs < 3000) return;
    await recordRecommendationInteraction({
      uid: event.params.userId,
      postId: event.params.postId,
      action: "dwell",
      eventId: `dwell_${event.params.postId}_${event.params.userId}`,
      occurredAt: after.lastSeenAt || admin.firestore.FieldValue.serverTimestamp(),
      eventVersionMillis: eventVersionMillis(event),
    });
  },
);

const updateNegativeInterestOnHiddenPost = onDocumentCreated(
  {
    document: "users/{userId}/hiddenPosts/{postId}",
    timeoutSeconds: 120,
    ...EMBEDDING_RUNTIME_OPTIONS,
  },
  async (event) => recordNegativeRecommendationInteraction({
    uid: event.params.userId,
    postId: event.params.postId,
    action: "hide_post",
    eventId: `hide_post_${event.params.postId}_${event.params.userId}`,
    occurredAt: event.data?.data()?.hiddenAt,
    eventVersionMillis: eventVersionMillis(event),
  }),
);

const updateNegativeInterestOnHiddenAuthor = onDocumentCreated(
  {
    document: "users/{userId}/hiddenPostAuthors/{authorId}",
    timeoutSeconds: 120,
    ...EMBEDDING_RUNTIME_OPTIONS,
  },
  async (event) => {
    const postId = cleanId(event.data?.data()?.sourcePostId);
    if (!postId) return;
    await recordNegativeRecommendationInteraction({
      uid: event.params.userId,
      postId,
      action: "hide_author",
      eventId: `hide_author_${event.params.authorId}_${event.params.userId}`,
      occurredAt: event.data?.data()?.hiddenAt,
      eventVersionMillis: eventVersionMillis(event),
    });
  },
);

const removeNegativeInterestOnUnhideAuthor = onDocumentDeleted(
  {
    document: "users/{userId}/hiddenPostAuthors/{authorId}",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (event) => {
    const postId = cleanId(event.data?.data()?.sourcePostId);
    if (!postId) return;
    await deactivateRecommendationInteraction({
      uid: event.params.userId,
      postId,
      action: "hide_author",
      eventId: `hide_author_${event.params.authorId}_${event.params.userId}`,
      eventVersionMillis: eventVersionMillis(event),
    });
  },
);

const updateNegativeInterestOnPostReport = onDocumentCreated(
  {
    document: "postReports/{reportId}",
    timeoutSeconds: 120,
    ...EMBEDDING_RUNTIME_OPTIONS,
  },
  async (event) => {
    const report = event.data?.data() || {};
    await recordNegativeRecommendationInteraction({
      uid: report.fromUid,
      postId: report.postId,
      action: "report",
      eventId: `report_${event.params.reportId}`,
      occurredAt: report.createdAt,
      eventVersionMillis: eventVersionMillis(event),
    });
  },
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
    ...EMBEDDING_RUNTIME_OPTIONS,
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
    ...EMBEDDING_RUNTIME_OPTIONS,
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

const retryFailedPostEmbeddings = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 540,
    ...EMBEDDING_RUNTIME_OPTIONS,
  },
  async () => {
    const snapshot = await db
      .collection("posts")
      .where("recommendationStatus", "==", "failed")
      .limit(EMBEDDING_RETRY_BATCH_SIZE)
      .get();

    let recoveredCount = 0;
    for (const doc of snapshot.docs) {
      const post = doc.data() || {};
      if (!isEligiblePost(post)) continue;
      try {
        await ensurePostEmbedding(doc.id, post, {
          forceRefresh: true,
        });
        recoveredCount += 1;
      } catch (error) {
        await markRecommendationFailure(doc.ref, error);
        console.error("retryFailedPostEmbeddings failed:", {
          postId: doc.id,
          error: error?.message || String(error),
        });
      }
    }

    console.info("retryFailedPostEmbeddings completed:", {
      scannedCount: snapshot.size,
      recoveredCount,
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
  retryFailedPostEmbeddings,
  updateInterestOnPostComment,
  updateInterestOnPostLike,
  updateInterestOnPostSave,
  updateInterestOnDwell,
  updateNegativeInterestOnHiddenPost,
  updateNegativeInterestOnHiddenAuthor,
  updateNegativeInterestOnPostReport,
  removeNegativeInterestOnUnhideAuthor,
  updateInterestOnQuoteOrRepost,
};
