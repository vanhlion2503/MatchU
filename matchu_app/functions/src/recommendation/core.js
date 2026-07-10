const { admin, db } = require("../shared/firebase");
const {
  EMBEDDING_MODEL,
  generatePostEmbedding,
} = require("./embedding");

const DECAY_FLOOR = 0.6;
const HALF_LIFE_DAYS = 3;
const MIN_SIMILARITY = 0.7;
const TRENDING_WINDOW_DAYS = 7;
const MAX_WEIGHT_CAP = 100;
const CANDIDATE_LIMIT = 180;
const CACHE_TTL_MS = 10 * 60 * 1000;
const CACHE_POST_POOL_SIZE = 140;
const INTERACTION_HISTORY_LIMIT = 500;

const ACTION_WEIGHTS = Object.freeze({
  like: 1.0,
  comment: 1.2,
  share: 1.5,
});

function toSafeUid(value) {
  return typeof value === "string" ? value.trim() : "";
}

function toMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  return null;
}

function parseVector(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((item) => typeof item === "number" && Number.isFinite(item));
}

function cosineSimilarity(a, b) {
  if (!a.length || !b.length || a.length !== b.length) return 0;

  let dot = 0;
  let magA = 0;
  let magB = 0;
  for (let index = 0; index < a.length; index += 1) {
    dot += a[index] * b[index];
    magA += a[index] * a[index];
    magB += b[index] * b[index];
  }

  if (magA === 0 || magB === 0) return 0;
  return dot / (Math.sqrt(magA) * Math.sqrt(magB));
}

function timeDecay(createdAtMillis, nowMillis = Date.now()) {
  if (!createdAtMillis) return DECAY_FLOOR;
  const ageDays = Math.max(0, (nowMillis - createdAtMillis) / 86400000);
  const decay = Math.pow(0.5, ageDays / HALF_LIFE_DAYS);
  return Math.max(DECAY_FLOOR, Math.min(1, decay));
}

function calculateTrendingScore(post, nowMillis = Date.now()) {
  const stats = post.stats || {};
  const createdAtMillis = toMillis(post.createdAt) || nowMillis;
  const engagement =
    ((Number(stats.likeCount) || 0) * 1.0) +
    ((Number(stats.commentCount) || 0) * 0.8) +
    ((Number(stats.shareCount) || 0) * 1.5);
  return (
    engagement +
    (Number(post.trendScore) || 0) +
    ((Number(post.trendBucket) || 0) * 0.25)
  ) * timeDecay(createdAtMillis, nowMillis);
}

function isEligiblePost(post) {
  return (
    post &&
    !post.deletedAt &&
    post.visibility === "public" &&
    (post.moderationStatus || "approved") === "approved" &&
    post.postType !== "repost"
  );
}

function resolveRatios(user, hasFollowing) {
  const effectiveCount = Number(user?.effectiveCount) || 0;
  const hasInterestVector = parseVector(user?.interestVector).length > 0;

  if (effectiveCount <= 0 || !hasInterestVector) {
    return hasFollowing
      ? { content: 0, trending: 0.6, following: 0.4, label: "cold_start" }
      : { content: 0, trending: 1, following: 0, label: "cold_start_trending" };
  }

  if (effectiveCount < 10) {
    return {
      content: 0.3,
      trending: 0.4,
      following: hasFollowing ? 0.3 : 0,
      label: "hybrid_exploration",
    };
  }

  return {
    content: 0.7,
    trending: 0.2,
    following: hasFollowing ? 0.1 : 0,
    label: "personalized",
  };
}

function recommendationCacheRef(uid) {
  return db
    .collection("users")
    .doc(uid)
    .collection("recommendationCache")
    .doc("feed");
}

async function invalidateRecommendationCache(uid, reason) {
  const normalizedUid = toSafeUid(uid);
  if (!normalizedUid) return;

  await recommendationCacheRef(normalizedUid).set(
    {
      invalidatedAt: admin.firestore.FieldValue.serverTimestamp(),
      invalidationReason: reason || "interaction",
      expiresAtMillis: 0,
    },
    { merge: true }
  );
}

async function fetchRestrictedAuthorIds(uid) {
  const hiddenSnap = await db
    .collection("users")
    .doc(uid)
    .collection("hiddenPostAuthors")
    .get();
  const blockedSnap = await db
    .collection("users")
    .doc(uid)
    .collection("blockedUsers")
    .get();

  return new Set([
    ...hiddenSnap.docs.map((doc) => String(doc.data()?.authorId || doc.id).trim()),
    ...blockedSnap.docs.map((doc) =>
      String(doc.data()?.blockedUserId || doc.id).trim()
    ),
  ].filter(Boolean));
}

async function ensurePostEmbedding(postId, postData) {
  const existingVector = parseVector(postData?.contentVector);
  if (existingVector.length > 0) return existingVector;
  if (!isEligiblePost({ ...postData, postType: postData?.postType || "post" })) {
    return [];
  }

  const vector = await generatePostEmbedding(postData || {});
  if (!vector.length) return [];

  await db.collection("posts").doc(postId).set(
    {
      contentVector: vector,
      contentEmbeddingModel: EMBEDDING_MODEL,
      contentVectorUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return vector;
}

async function loadCandidatePosts() {
  const snapshot = await db
    .collection("posts")
    .where("visibility", "==", "public")
    .where("moderationStatus", "==", "approved")
    .orderBy("createdAt", "desc")
    .limit(CANDIDATE_LIMIT)
    .get();

  return snapshot.docs
    .map((doc) => ({ id: doc.id, data: doc.data() || {} }))
    .filter((post) => isEligiblePost(post.data));
}

async function buildRecommendationPool(uid) {
  const startedAt = Date.now();
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new Error("User profile not found.");
  }

  const user = userSnap.data() || {};
  const following = new Set(
    Array.isArray(user.following)
      ? user.following.filter((id) => typeof id === "string" && id !== uid)
      : []
  );
  const restrictedAuthorIds = await fetchRestrictedAuthorIds(uid);
  const ratios = resolveRatios(user, following.size > 0);
  const userVector = parseVector(user.interestVector);
  const nowMillis = Date.now();
  const trendingCutoff = nowMillis - (TRENDING_WINDOW_DAYS * 86400000);
  const candidates = await loadCandidatePosts();
  const scored = [];

  for (const candidate of candidates) {
    const post = candidate.data;
    const authorId = toSafeUid(post.authorId);
    const referenceAuthorId = toSafeUid(post.referencePost?.authorId);
    if (!authorId || authorId === uid) continue;
    if (restrictedAuthorIds.has(authorId) || restrictedAuthorIds.has(referenceAuthorId)) {
      continue;
    }

    const createdAtMillis = toMillis(post.createdAt) || nowMillis;
    const postVector = parseVector(post.contentVector);
    const similarity = cosineSimilarity(userVector, postVector);
    const contentBasedScore =
      similarity >= MIN_SIMILARITY
        ? similarity * timeDecay(createdAtMillis, nowMillis)
        : 0;
    const rawTrendingScore =
      createdAtMillis >= trendingCutoff
        ? calculateTrendingScore(post, nowMillis)
        : 0;
    const followingBoost = following.has(authorId) ? 1 : 0;

    if (contentBasedScore <= 0 && rawTrendingScore <= 0 && followingBoost <= 0) {
      continue;
    }

    scored.push({
      postId: candidate.id,
      contentBasedScore,
      rawTrendingScore,
      followingBoost,
      createdAtMillis,
    });
  }

  const maxTrendingScore = scored.reduce(
    (max, item) => Math.max(max, item.rawTrendingScore),
    0
  );

  const ranked = scored.map((item) => {
    const trendingScore =
      maxTrendingScore > 0 ? item.rawTrendingScore / maxTrendingScore : 0;
    const finalScore =
      (item.contentBasedScore * ratios.content) +
      (trendingScore * ratios.trending) +
      (item.followingBoost * ratios.following);
    return {
      ...item,
      trendingScore,
      finalScore,
    };
  });

  ranked.sort((a, b) => {
    if (b.finalScore !== a.finalScore) return b.finalScore - a.finalScore;
    return b.createdAtMillis - a.createdAtMillis;
  });

  const pool = ranked.slice(0, CACHE_POST_POOL_SIZE);
  return {
    postIds: pool.map((item) => item.postId),
    scoresByPostId: Object.fromEntries(
      pool.map((item) => [
        item.postId,
        {
          contentBasedScore: item.contentBasedScore,
          trendingScore: item.trendingScore,
          followingBoost: item.followingBoost,
          finalScore: item.finalScore,
        },
      ])
    ),
    metadata: {
      totalRecommended: pool.length,
      contentBasedCount: ranked.filter((item) => item.contentBasedScore > 0).length,
      trendingCount: ranked.filter((item) => item.rawTrendingScore > 0).length,
      followingCount: ranked.filter((item) => item.followingBoost > 0).length,
      processingTimeMs: Date.now() - startedAt,
      ratio: ratios.label,
      embeddingModel: EMBEDDING_MODEL,
    },
  };
}

async function getOrBuildRecommendationPool(uid, { forceRefresh = false } = {}) {
  const cacheRef = recommendationCacheRef(uid);
  const cacheSnap = forceRefresh ? null : await cacheRef.get();
  const nowMillis = Date.now();

  if (
    cacheSnap?.exists &&
    Number(cacheSnap.data()?.expiresAtMillis || 0) > nowMillis &&
    Array.isArray(cacheSnap.data()?.postIds)
  ) {
    return {
      postIds: cacheSnap.data().postIds,
      scoresByPostId: cacheSnap.data().scoresByPostId || {},
      metadata: {
        ...(cacheSnap.data().metadata || {}),
        cacheHit: true,
      },
    };
  }

  const pool = await buildRecommendationPool(uid);
  await cacheRef.set(
    {
      ...pool,
      expiresAtMillis: nowMillis + CACHE_TTL_MS,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return {
    ...pool,
    metadata: {
      ...pool.metadata,
      cacheHit: false,
    },
  };
}

function mergeInterestVector(oldVector, postVector, oldWeight, actionWeight) {
  if (!postVector.length) return [];
  if (!oldVector.length || oldVector.length !== postVector.length) {
    return postVector;
  }

  const effectiveOldWeight = Math.min(
    Math.max(0, Number(oldWeight) || 0),
    Math.max(0, MAX_WEIGHT_CAP - actionWeight)
  );
  const totalWeight = effectiveOldWeight + actionWeight;
  if (totalWeight <= 0) return postVector;

  return postVector.map(
    (value, index) =>
      ((oldVector[index] * effectiveOldWeight) + (value * actionWeight)) /
      totalWeight
  );
}

function interactionRef(uid, eventId) {
  return db
    .collection("users")
    .doc(uid)
    .collection("recommendationInteractions")
    .doc(eventId);
}

async function recordRecommendationInteraction({
  uid,
  postId,
  action,
  eventId,
  occurredAt,
}) {
  const normalizedUid = toSafeUid(uid);
  const normalizedPostId = typeof postId === "string" ? postId.trim() : "";
  if (!normalizedUid || !normalizedPostId || !ACTION_WEIGHTS[action]) return;

  const postRef = db.collection("posts").doc(normalizedPostId);
  const postSnap = await postRef.get();
  if (!postSnap.exists) return;

  const postData = postSnap.data() || {};
  if (!isEligiblePost(postData) && postData.postType !== "repost") return;

  const vector = await ensurePostEmbedding(normalizedPostId, postData);
  if (!vector.length) return;

  const actionWeight = ACTION_WEIGHTS[action];
  const userRef = db.collection("users").doc(normalizedUid);
  const interactionId =
    typeof eventId === "string" && eventId.trim()
      ? eventId.trim().replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 140)
      : `${action}_${normalizedPostId}_${Date.now()}`;

  await db.runTransaction(async (tx) => {
    const [userSnap, interactionSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(interactionRef(normalizedUid, interactionId)),
    ]);
    if (!userSnap.exists || interactionSnap.exists) return;

    const user = userSnap.data() || {};
    const oldVector = parseVector(user.interestVector);
    const oldWeight = Number(user.interestWeight) || 0;
    const oldEffectiveCount = Number(user.effectiveCount) || 0;
    const nextVector = mergeInterestVector(
      oldVector,
      vector,
      oldWeight,
      actionWeight
    );
    if (!nextVector.length) return;

    tx.set(interactionRef(normalizedUid, interactionId), {
      postId: normalizedPostId,
      action,
      actionWeight,
      postVector: vector,
      createdAt: occurredAt || admin.firestore.FieldValue.serverTimestamp(),
      createdAtMillis: Date.now(),
    });

    tx.set(
      userRef,
      {
        interestVector: nextVector,
        interestWeight: Math.min(MAX_WEIGHT_CAP, oldWeight + actionWeight),
        effectiveCount: oldEffectiveCount + actionWeight,
        interestUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        recommendationCacheInvalidatedAt:
          admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  await invalidateRecommendationCache(normalizedUid, action);
}

async function rebuildUserInterestVector(uid) {
  const normalizedUid = toSafeUid(uid);
  if (!normalizedUid) return false;

  const interactionsSnap = await db
    .collection("users")
    .doc(normalizedUid)
    .collection("recommendationInteractions")
    .orderBy("createdAtMillis", "desc")
    .limit(INTERACTION_HISTORY_LIMIT)
    .get();

  if (interactionsSnap.empty) return false;

  const nowMillis = Date.now();
  let totalWeight = 0;
  let rebuiltVector = [];
  let effectiveCount = 0;

  for (const doc of interactionsSnap.docs) {
    const interaction = doc.data() || {};
    const vector = parseVector(interaction.postVector);
    const actionWeight = Number(interaction.actionWeight) || 0;
    if (!vector.length || actionWeight <= 0) continue;

    const occurredAtMillis =
      Number(interaction.createdAtMillis) ||
      toMillis(interaction.createdAt) ||
      nowMillis;
    const decayedWeight =
      actionWeight * timeDecay(occurredAtMillis, nowMillis);
    if (decayedWeight <= 0) continue;

    if (!rebuiltVector.length || rebuiltVector.length !== vector.length) {
      rebuiltVector = vector;
      totalWeight = Math.min(MAX_WEIGHT_CAP, decayedWeight);
      effectiveCount += actionWeight;
      continue;
    }

    const nextTotalWeight = Math.min(MAX_WEIGHT_CAP, totalWeight + decayedWeight);
    rebuiltVector = vector.map((value, index) => {
      return (
        (rebuiltVector[index] * totalWeight) +
        (value * decayedWeight)
      ) / (totalWeight + decayedWeight);
    });
    totalWeight = nextTotalWeight;
    effectiveCount += actionWeight;
  }

  if (!rebuiltVector.length) return false;

  await db.collection("users").doc(normalizedUid).set(
    {
      interestVector: rebuiltVector,
      interestWeight: Math.min(MAX_WEIGHT_CAP, totalWeight),
      effectiveCount,
      interestUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      recommendationCacheInvalidatedAt:
        admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  await invalidateRecommendationCache(normalizedUid, "scheduled_rebuild");
  return true;
}

module.exports = {
  ACTION_WEIGHTS,
  CACHE_POST_POOL_SIZE,
  CACHE_TTL_MS,
  CANDIDATE_LIMIT,
  DECAY_FLOOR,
  HALF_LIFE_DAYS,
  MAX_WEIGHT_CAP,
  MIN_SIMILARITY,
  TRENDING_WINDOW_DAYS,
  buildRecommendationPool,
  calculateTrendingScore,
  cosineSimilarity,
  ensurePostEmbedding,
  getOrBuildRecommendationPool,
  invalidateRecommendationCache,
  isEligiblePost,
  parseVector,
  rebuildUserInterestVector,
  recordRecommendationInteraction,
  recommendationCacheRef,
  timeDecay,
  toMillis,
  toSafeUid,
};
