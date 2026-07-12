const { admin, db } = require("../shared/firebase");
const {
  DEFAULT_EMBEDDING_MODEL,
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
  embeddingSignatureForPost,
  generatePostEmbedding,
  normalizeEmbeddingText,
} = require("./embedding");
const {
  RECENT_CANDIDATE_LIMIT,
  buildEmbeddingSearchKey,
  buildRecommendationIndexMetadata,
  calculatePopularitySignal,
  loadFollowingCandidates,
  loadPostsByIds,
  loadRecentCandidates,
  loadTrendingCandidateIds,
  loadVectorCandidateMatches,
  recommendationIndexRef,
} = require("./retrieval");

const DECAY_FLOOR = 0.6;
const HALF_LIFE_DAYS = 3;
const MIN_SIMILARITY = 0.7;
const TRENDING_WINDOW_DAYS = 7;
const MAX_WEIGHT_CAP = 100;
const CANDIDATE_LIMIT = RECENT_CANDIDATE_LIMIT;
const CACHE_TTL_MS = 10 * 60 * 1000;
const CACHE_POST_POOL_SIZE = 140;
const INTERACTION_HISTORY_LIMIT = 500;
const TRENDING_FRESHNESS_BASELINE = 0.15;
const INTEREST_HALF_LIFE_DAYS = 30;
const MAX_POSTS_PER_AUTHOR_IN_PRIMARY_POOL = 3;
const RECOMMENDATION_ALGORITHM_VERSION = "hybrid_vector_v3_sessions";
const RECOMMENDATION_FEED_STATE_PATH = "system/recommendationFeedState";
const RECENT_SEEN_WINDOW_MS = 30 * 60 * 1000;
const IMPRESSION_FREQUENCY_WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_SEEN_PENALTY = 0.40;
const QUALIFIED_DWELL_MS = 5000;

const ACTION_WEIGHTS = Object.freeze({
  dwell: 0.35,
  like: 1.0,
  comment: 1.2,
  save: 1.3,
  share: 1.5,
});
const NEGATIVE_ACTION_WEIGHTS = Object.freeze({
  hide_post: 1.0,
  hide_author: 1.4,
  report: 2.0,
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
  if (value.some((item) => typeof item !== "number" || !Number.isFinite(item))) {
    return [];
  }
  return value;
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

function exponentialDecay(
  createdAtMillis,
  nowMillis = Date.now(),
  halfLifeDays = HALF_LIFE_DAYS
) {
  if (!createdAtMillis) return 0;
  const ageDays = Math.max(0, (nowMillis - createdAtMillis) / 86400000);
  return Math.max(0, Math.min(1, Math.pow(0.5, ageDays / halfLifeDays)));
}

function calculateTrendingScore(post, nowMillis = Date.now()) {
  const createdAtMillis = toMillis(post.createdAt) || nowMillis;
  return (
    calculatePopularitySignal(post) + TRENDING_FRESHNESS_BASELINE
  ) * exponentialDecay(createdAtMillis, nowMillis);
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
  const modelMatches =
    (user?.interestEmbeddingModel || DEFAULT_EMBEDDING_MODEL) ===
      EMBEDDING_MODEL;
  const hasInterestVector = modelMatches &&
    parseVector(user?.interestVector).length === EMBEDDING_DIMENSIONS;

  if (effectiveCount <= 0 || !hasInterestVector) {
    return hasFollowing
      ? { content: 0, trending: 0.6, following: 0.4, label: "cold_start" }
      : { content: 0, trending: 1, following: 0, label: "cold_start_trending" };
  }

  if (effectiveCount < 10) {
    return normalizeRatios({
      content: 0.3,
      trending: 0.4,
      following: hasFollowing ? 0.3 : 0,
      label: "hybrid_exploration",
    });
  }

  return normalizeRatios({
    content: 0.7,
    trending: 0.2,
    following: hasFollowing ? 0.1 : 0,
    label: "personalized",
  });
}

function normalizeRatios(ratios) {
  const total = ratios.content + ratios.trending + ratios.following;
  if (total <= 0) return ratios;
  return {
    ...ratios,
    content: ratios.content / total,
    trending: ratios.trending / total,
    following: ratios.following / total,
  };
}

function recommendationCacheRef(uid) {
  return db
    .collection("users")
    .doc(uid)
    .collection("recommendationCache")
    .doc("feed");
}

function recommendationFeedStateRef() {
  return db.doc(RECOMMENDATION_FEED_STATE_PATH);
}

async function bumpRecommendationFeedRevision(reason = "post_changed") {
  await recommendationFeedStateRef().set({
    revision: admin.firestore.FieldValue.increment(1),
    reason,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
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

async function fetchRestrictions(uid) {
  const userRef = db.collection("users").doc(uid);
  const [hiddenAuthorsSnap, hiddenPostsSnap, blockedSnap, blockedBySnap] =
    await Promise.all([
      userRef.collection("hiddenPostAuthors").get(),
      userRef.collection("hiddenPosts").get(),
      userRef.collection("blockedUsers").get(),
      userRef.collection("blockedBy").get(),
    ]);

  const restrictedAuthorIds = new Set([
    ...hiddenAuthorsSnap.docs.map((doc) =>
      String(doc.data()?.authorId || doc.id).trim()
    ),
    ...blockedSnap.docs.map((doc) =>
      String(doc.data()?.blockedUserId || doc.id).trim()
    ),
    ...blockedBySnap.docs.map((doc) =>
      String(doc.data()?.blockerId || doc.id).trim()
    ),
  ].filter(Boolean));

  const hiddenPostIds = new Set(hiddenPostsSnap.docs.map((doc) =>
    String(doc.data()?.postId || doc.id).trim()
  ).filter(Boolean));

  return { restrictedAuthorIds, hiddenPostIds };
}

function isPostEmbeddingCurrent(postData) {
  const signature = embeddingSignatureForPost(postData || {});
  const normalizedText = normalizeEmbeddingText({
    content: postData?.content,
    tags: postData?.tags,
  });
  const existingVector = parseVector(postData?.contentVector);
  const modelMatches = postData?.contentEmbeddingModel === EMBEDDING_MODEL;
  const signatureMatches = postData?.contentEmbeddingSignature === signature;
  const dimensionsMatch =
    Number(postData?.contentVectorDimensions || 0) === existingVector.length &&
    (existingVector.length === 0 || existingVector.length === EMBEDDING_DIMENSIONS);
  if (!normalizedText) {
    return modelMatches &&
      signatureMatches &&
      existingVector.length === 0 &&
      postData?.contentVectorSearchKey === null;
  }
  const expectedSearchKey = buildEmbeddingSearchKey(
    signature,
    existingVector.length
  );
  return modelMatches && signatureMatches && dimensionsMatch &&
    existingVector.length > 0 &&
    postData?.contentVectorSearchKey === expectedSearchKey;
}

function hasReusablePostEmbedding(postData) {
  const vector = parseVector(postData?.contentVector);
  if (vector.length !== EMBEDDING_DIMENSIONS) return false;
  return postData?.contentEmbeddingModel === EMBEDDING_MODEL &&
    postData?.contentEmbeddingSignature ===
      embeddingSignatureForPost(postData || {}) &&
    Number(postData?.contentVectorDimensions || 0) === vector.length;
}

async function ensurePostEmbedding(postId, postData, { forceRefresh = false } = {}) {
  const existingVector = parseVector(postData?.contentVector);
  if (!forceRefresh && isPostEmbeddingCurrent(postData)) {
    const expectedStatus = existingVector.length ? "ready" : "discovery_only";
    if (postData?.recommendationStatus !== expectedStatus) {
      await db.collection("posts").doc(postId).set({
        recommendationStatus: expectedStatus,
        recommendationErrorCode: admin.firestore.FieldValue.delete(),
        recommendationAttemptCount: admin.firestore.FieldValue.increment(0),
        recommendationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return existingVector;
  }
  if (!isEligiblePost({ ...postData, postType: postData?.postType || "post" })) {
    return [];
  }

  const signature = embeddingSignatureForPost(postData || {});
  const normalizedText = normalizeEmbeddingText({
    content: postData?.content,
    tags: postData?.tags,
  });
  const vector = !normalizedText
    ? []
    : (!forceRefresh && hasReusablePostEmbedding(postData)
      ? existingVector
      : await generatePostEmbedding(postData || {}));
  if (normalizedText && vector.length !== EMBEDDING_DIMENSIONS) return [];

  const postRef = db.collection("posts").doc(postId);
  const searchKey = vector.length
    ? buildEmbeddingSearchKey(signature, vector.length)
    : null;
  let didWrite = false;
  await db.runTransaction(async (tx) => {
    didWrite = false;
    const latestSnap = await tx.get(postRef);
    if (!latestSnap.exists) return;
    const latestData = latestSnap.data() || {};
    if (embeddingSignatureForPost(latestData) !== signature ||
        !isEligiblePost(latestData)) {
      return;
    }

    tx.set(postRef, {
      contentVector: vector,
      contentEmbeddingModel: EMBEDDING_MODEL,
      contentEmbeddingSignature: signature,
      contentVectorDimensions: vector.length,
      contentVectorSearchKey: searchKey,
      contentVectorUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      recommendationStatus: vector.length ? "ready" : "discovery_only",
      recommendationErrorCode: admin.firestore.FieldValue.delete(),
      recommendationAttemptCount: admin.firestore.FieldValue.increment(1),
      recommendationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const indexData = {
      ...buildRecommendationIndexMetadata(postId, latestData),
      embeddingModel: vector.length
        ? EMBEDDING_MODEL
        : admin.firestore.FieldValue.delete(),
      embeddingSignature: vector.length
        ? signature
        : admin.firestore.FieldValue.delete(),
      embeddingDimensions: vector.length
        ? vector.length
        : admin.firestore.FieldValue.delete(),
      embedding: vector.length
        ? admin.firestore.FieldValue.vector(vector)
        : admin.firestore.FieldValue.delete(),
      embeddingUpdatedAt: vector.length
        ? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.delete(),
    };
    tx.set(recommendationIndexRef(postId), indexData, { merge: true });
    didWrite = true;
  });
  return didWrite ? vector : [];
}

function retrievalErrorCode(error) {
  const code = error?.code;
  if (typeof code === "number" || typeof code === "string") {
    return String(code);
  }
  return "unknown";
}

async function loadHybridCandidatePosts({ userVector, following, nowMillis }) {
  const vectorSearchEnabled =
    process.env.RECOMMENDATION_VECTOR_SEARCH_ENABLED !== "false" &&
    userVector.length === EMBEDDING_DIMENSIONS;

  const [recentResult, vectorResult, trendingResult, followingResult] =
    await Promise.allSettled([
      loadRecentCandidates(),
      vectorSearchEnabled
        ? loadVectorCandidateMatches(userVector, {
          minSimilarity: MIN_SIMILARITY,
        })
        : Promise.resolve([]),
      loadTrendingCandidateIds(nowMillis),
      following.size > 0
        ? loadFollowingCandidates(following)
        : Promise.resolve([]),
    ]);

  if (recentResult.status === "rejected") throw recentResult.reason;

  const vectorMatches = vectorResult.status === "fulfilled"
    ? vectorResult.value
    : [];
  const trendingIds = trendingResult.status === "fulfilled"
    ? trendingResult.value
    : [];
  const followingCandidates = followingResult.status === "fulfilled"
    ? followingResult.value
    : [];

  if (vectorResult.status === "rejected") {
    console.warn("Vector candidate retrieval fell back to hybrid discovery:", {
      code: retrievalErrorCode(vectorResult.reason),
      message: vectorResult.reason?.message || String(vectorResult.reason),
    });
  }
  if (trendingResult.status === "rejected") {
    console.warn("Trending index retrieval fell back to recent posts:", {
      code: retrievalErrorCode(trendingResult.reason),
      message: trendingResult.reason?.message || String(trendingResult.reason),
    });
  }
  if (followingResult.status === "rejected") {
    console.warn("Following candidate retrieval fell back to other sources:", {
      code: retrievalErrorCode(followingResult.reason),
      message: followingResult.reason?.message || String(followingResult.reason),
    });
  }

  const indexedIds = new Set([
    ...vectorMatches.map((item) => item.postId),
    ...trendingIds,
  ]);
  let indexedPosts = [];
  let indexedHydrationError = null;
  if (indexedIds.size > 0) {
    try {
      indexedPosts = await loadPostsByIds(indexedIds);
    } catch (error) {
      indexedHydrationError = retrievalErrorCode(error);
      console.warn("Indexed candidate hydration failed:", {
        code: indexedHydrationError,
        message: error?.message || String(error),
      });
    }
  }

  const similarities = new Map(
    vectorMatches.map((item) => [item.postId, item.similarity])
  );
  const byPostId = new Map();
  const addCandidates = (candidates, source) => {
    for (const candidate of candidates) {
      if (!candidate?.id || !candidate.data) continue;
      const existing = byPostId.get(candidate.id);
      if (existing) {
        existing.sources.add(source);
        if (similarities.has(candidate.id)) {
          existing.vectorSimilarity = similarities.get(candidate.id);
        }
        continue;
      }
      byPostId.set(candidate.id, {
        id: candidate.id,
        data: candidate.data,
        vectorSimilarity: similarities.get(candidate.id),
        sources: new Set([source]),
      });
    }
  };

  addCandidates(recentResult.value, "recent");
  addCandidates(followingCandidates, "following");
  addCandidates(indexedPosts, "index");

  const candidates = Array.from(byPostId.values())
    .filter((candidate) => isEligiblePost(candidate.data));
  return {
    candidates,
    metadata: {
      retrievalMode: vectorSearchEnabled
        ? (vectorResult.status === "fulfilled"
          ? "hybrid_vector"
          : "hybrid_fallback")
        : "hybrid_discovery",
      candidateCount: candidates.length,
      recentCandidateCount: recentResult.value.length,
      vectorCandidateCount: vectorMatches.length,
      trendingCandidateCount: trendingIds.length,
      followingCandidateCount: followingCandidates.length,
      vectorSearchUsed: vectorSearchEnabled && vectorResult.status === "fulfilled",
      vectorSearchFallbackCode:
        vectorResult.status === "rejected"
          ? retrievalErrorCode(vectorResult.reason)
          : null,
      trendingSearchFallbackCode:
        trendingResult.status === "rejected"
          ? retrievalErrorCode(trendingResult.reason)
          : null,
      followingSearchFallbackCode:
        followingResult.status === "rejected"
          ? retrievalErrorCode(followingResult.reason)
          : null,
      indexedHydrationError,
    },
  };
}

function seededRandom(seed) {
  let state = 2166136261;
  for (const character of String(seed || "feed")) {
    state ^= character.charCodeAt(0);
    state = Math.imul(state, 16777619);
  }
  return () => {
    state += 0x6D2B79F5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffleScoreBands(ranked, seed, bandSize = 0.05) {
  const random = seededRandom(seed);
  const result = [];
  for (let index = 0; index < ranked.length;) {
    const band = [ranked[index]];
    const bandScore = ranked[index].finalScore;
    index += 1;
    while (index < ranked.length &&
      Math.abs(ranked[index].finalScore - bandScore) <= bandSize) {
      band.push(ranked[index]);
      index += 1;
    }
    for (let cursor = band.length - 1; cursor > 0; cursor -= 1) {
      const target = Math.floor(random() * (cursor + 1));
      [band[cursor], band[target]] = [band[target], band[cursor]];
    }
    result.push(...band);
  }
  return result;
}

function calculateSeenPenalty(impression, nowMillis = Date.now()) {
  if (!impression) return 0;
  const lastSeenAt = toMillis(impression.lastSeenAt);
  const windowStartedAt = toMillis(impression.frequencyWindowStartedAt);
  const recentSeenPenalty = lastSeenAt &&
    nowMillis - lastSeenAt < RECENT_SEEN_WINDOW_MS ? 0.22 : 0;
  const frequencyCount = windowStartedAt &&
    nowMillis - windowStartedAt < IMPRESSION_FREQUENCY_WINDOW_MS
    ? Number(impression.impressionCount24h) || 0
    : 0;
  const impressionFrequencyPenalty = frequencyCount >= 3
    ? Math.min(0.12, 0.04 * (frequencyCount - 2))
    : 0;
  const qualifiedDwellPenalty = Number(impression.lastDwellMs) >=
    QUALIFIED_DWELL_MS ? 0.06 : 0;
  return Math.min(
    MAX_SEEN_PENALTY,
    recentSeenPenalty + impressionFrequencyPenalty + qualifiedDwellPenalty,
  );
}

function isFrequencyCapped(impression, nowMillis = Date.now()) {
  const windowStartedAt = toMillis(impression?.frequencyWindowStartedAt);
  return Boolean(
    windowStartedAt &&
    nowMillis - windowStartedAt < IMPRESSION_FREQUENCY_WINDOW_MS &&
    (Number(impression?.impressionCount24h) || 0) >= 3,
  );
}

async function loadFeedImpressions(uid) {
  const snap = await db.collection("users").doc(uid)
    .collection("feedImpressions").limit(INTERACTION_HISTORY_LIMIT).get();
  return new Map(snap.docs.map((doc) => [doc.id, doc.data() || {}]));
}

function composeDiversePool(ranked, limit, seed, ratioLabel) {
  const random = seededRandom(`${seed}:exploration`);
  const available = [...ranked];
  const selected = [];
  const selectedIds = new Set();
  const take = (predicate, count, randomize = false) => {
    let candidates = available.filter((item) =>
      !selectedIds.has(item.postId) && predicate(item));
    if (randomize) candidates = candidates.sort(() => random() - 0.5);
    for (const item of candidates.slice(0, count)) {
      selected.push(item);
      selectedIds.add(item.postId);
    }
  };

  // Cold-start reserves more discovery; established profiles approximate 14/3/2/1.
  const explorationRatio = ratioLabel.startsWith("cold_start") ? 0.20 : 0.10;
  while (selected.length < limit && selected.length < ranked.length) {
    const batchSize = Math.min(20, limit - selected.length);
    const followingCount = Math.round(batchSize * 0.05);
    const trendingCount = Math.round(batchSize * 0.15);
    const explorationCount = Math.max(1, Math.round(batchSize * explorationRatio));
    const personalizedCount = Math.max(
      0,
      batchSize - followingCount - trendingCount - explorationCount,
    );
    const before = selected.length;
    take((item) => item.contentBasedScore > 0, personalizedCount);
    take((item) => item.rawTrendingScore > 0, trendingCount);
    take(() => true, explorationCount, true);
    take((item) => item.followingBoost > 0, followingCount);
    take(() => true, batchSize - (selected.length - before));
    if (selected.length === before) break;
  }
  return selected;
}

async function buildRecommendationPool(uid, { seed = `${uid}:${Date.now()}` } = {}) {
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
  const { restrictedAuthorIds, hiddenPostIds } = await fetchRestrictions(uid);
  for (const restrictedAuthorId of restrictedAuthorIds) {
    following.delete(restrictedAuthorId);
  }
  const ratios = resolveRatios(user, following.size > 0);
  const parsedUserVector = parseVector(user.interestVector);
  const userVector =
    (user.interestEmbeddingModel || DEFAULT_EMBEDDING_MODEL) === EMBEDDING_MODEL &&
    parsedUserVector.length === EMBEDDING_DIMENSIONS
      ? parsedUserVector
      : [];
  const parsedNegativeVector = parseVector(user.negativeInterestVector);
  const negativeUserVector =
    user.negativeInterestEmbeddingModel === EMBEDDING_MODEL &&
    parsedNegativeVector.length === EMBEDDING_DIMENSIONS
      ? parsedNegativeVector
      : [];
  const nowMillis = Date.now();
  const trendingCutoff = nowMillis - (TRENDING_WINDOW_DAYS * 86400000);
  const [retrieval, impressions] = await Promise.all([
    loadHybridCandidatePosts({
    userVector,
    following,
    nowMillis,
    }),
    loadFeedImpressions(uid),
  ]);
  const candidates = retrieval.candidates;
  const scored = [];

  for (const candidate of candidates) {
    const post = candidate.data;
    if (hiddenPostIds.has(candidate.id)) continue;
    const authorId = toSafeUid(post.authorId);
    const referenceAuthorId = toSafeUid(post.referencePost?.authorId);
    if (!authorId || authorId === uid) continue;
    if (restrictedAuthorIds.has(authorId) || restrictedAuthorIds.has(referenceAuthorId)) {
      continue;
    }

    const createdAtMillis = toMillis(post.createdAt) || nowMillis;
    const postVector = isPostEmbeddingCurrent(post)
      ? parseVector(post.contentVector)
      : [];
    const similarity = Number.isFinite(candidate.vectorSimilarity)
      ? candidate.vectorSimilarity
      : cosineSimilarity(userVector, postVector);
    const contentBasedScore =
      similarity >= MIN_SIMILARITY
        ? similarity * timeDecay(createdAtMillis, nowMillis)
        : 0;
    const negativeSimilarity = negativeUserVector.length
      ? Math.max(0, cosineSimilarity(negativeUserVector, postVector))
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
      authorId,
      contentBasedScore,
      rawTrendingScore,
      followingBoost,
      negativeSimilarity,
      createdAtMillis,
      seenPenalty: calculateSeenPenalty(impressions.get(candidate.id), nowMillis),
      recentlySeen: (() => {
        const lastSeenAt = toMillis(impressions.get(candidate.id)?.lastSeenAt);
        return Boolean(lastSeenAt && nowMillis - lastSeenAt < RECENT_SEEN_WINDOW_MS);
      })(),
      frequencyCapped: isFrequencyCapped(impressions.get(candidate.id), nowMillis),
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
    const adjustedFinalScore = Math.max(
      0,
      finalScore - (item.negativeSimilarity * 0.35) - item.seenPenalty,
    );
    return {
      ...item,
      trendingScore,
      finalScore: adjustedFinalScore,
    };
  });

  ranked.sort((a, b) => {
    if (b.finalScore !== a.finalScore) return b.finalScore - a.finalScore;
    return b.createdAtMillis - a.createdAtMillis;
  });

  const unseenRanked = ranked.filter((item) =>
    !item.recentlySeen && !item.frequencyCapped);
  // Capped/just-seen posts only return when the unseen candidate supply is short.
  const seenFallback = ranked.filter((item) =>
    item.recentlySeen || item.frequencyCapped);
  const bandShuffled = shuffleScoreBands(
    [...unseenRanked, ...seenFallback],
    seed,
  );
  const composed = composeDiversePool(
    bandShuffled,
    CACHE_POST_POOL_SIZE,
    seed,
    ratios.label,
  );
  const pool = diversifyByAuthor(composed, CACHE_POST_POOL_SIZE);
  return {
    postIds: pool.map((item) => item.postId),
    scoresByPostId: Object.fromEntries(
      pool.map((item) => [
        item.postId,
        {
          contentBasedScore: item.contentBasedScore,
          trendingScore: item.trendingScore,
          followingBoost: item.followingBoost,
          seenPenalty: item.seenPenalty,
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
      embeddingDimensions: EMBEDDING_DIMENSIONS,
      algorithmVersion: RECOMMENDATION_ALGORITHM_VERSION,
      seed,
      recentSeenExcludedCount: unseenRanked.length >= CACHE_POST_POOL_SIZE
        ? seenFallback.length
        : Math.min(seenFallback.length, CACHE_POST_POOL_SIZE - unseenRanked.length),
      impressionCount: impressions.size,
      ...retrieval.metadata,
    },
  };
}

function diversifyByAuthor(ranked, limit) {
  if (!Array.isArray(ranked) || limit <= 0) return [];
  const selected = [];
  const deferred = [];
  const authorCounts = new Map();

  for (const item of ranked) {
    const authorId = toSafeUid(item?.authorId);
    const count = authorCounts.get(authorId) || 0;
    if (authorId && count >= MAX_POSTS_PER_AUTHOR_IN_PRIMARY_POOL) {
      deferred.push(item);
      continue;
    }
    selected.push(item);
    if (authorId) authorCounts.set(authorId, count + 1);
    if (selected.length >= limit) return selected;
  }

  for (const item of deferred) {
    selected.push(item);
    if (selected.length >= limit) break;
  }
  return selected;
}

async function getOrBuildRecommendationPool(
  uid,
  { forceRefresh = false, seed = `${uid}:${Date.now()}` } = {},
) {
  const cacheRef = recommendationCacheRef(uid);
  const [cacheSnap, feedStateSnap] = await Promise.all([
    forceRefresh ? Promise.resolve(null) : cacheRef.get(),
    recommendationFeedStateRef().get(),
  ]);
  const nowMillis = Date.now();
  const feedRevision = Number(feedStateSnap.data()?.revision) || 0;

  if (
    cacheSnap?.exists &&
    Number(cacheSnap.data()?.expiresAtMillis || 0) > nowMillis &&
    Number(cacheSnap.data()?.feedRevision || 0) === feedRevision &&
    cacheSnap.data()?.metadata?.algorithmVersion ===
      RECOMMENDATION_ALGORITHM_VERSION &&
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

  const pool = await buildRecommendationPool(uid, { seed });
  await cacheRef.set(
    {
      ...pool,
      feedRevision,
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
  eventVersionMillis = Date.now(),
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

  let didActivate = false;
  await db.runTransaction(async (tx) => {
    const [userSnap, interactionSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(interactionRef(normalizedUid, interactionId)),
    ]);
    if (!userSnap.exists) return;

    const existingInteraction = interactionSnap.data() || {};
    const existingVersion = Number(existingInteraction.eventVersionMillis) || 0;
    if (interactionSnap.exists && existingVersion > eventVersionMillis) return;
    if (interactionSnap.exists && existingInteraction.active !== false) return;

    const user = userSnap.data() || {};
    const userModelMatches =
      (user.interestEmbeddingModel || DEFAULT_EMBEDDING_MODEL) ===
        EMBEDDING_MODEL;
    const oldVector = userModelMatches ? parseVector(user.interestVector) : [];
    const oldWeight = userModelMatches ? Number(user.interestWeight) || 0 : 0;
    const oldEffectiveCount = userModelMatches
      ? Number(user.effectiveCount) || 0
      : 0;
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
      active: true,
      embeddingModel: EMBEDDING_MODEL,
      vectorDimensions: vector.length,
      eventVersionMillis,
      createdAt: occurredAt || admin.firestore.FieldValue.serverTimestamp(),
      createdAtMillis: toMillis(occurredAt) || Date.now(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(
      userRef,
      {
        interestVector: nextVector,
        interestWeight: Math.min(MAX_WEIGHT_CAP, oldWeight + actionWeight),
        effectiveCount: oldEffectiveCount + actionWeight,
        interestEmbeddingModel: EMBEDDING_MODEL,
        interestVectorDimensions: vector.length,
        interestUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        recommendationCacheInvalidatedAt:
          admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    didActivate = true;
  });

  if (didActivate) {
    await invalidateRecommendationCache(normalizedUid, action);
  }
}

async function deactivateRecommendationInteraction({
  uid,
  postId,
  action,
  eventId,
  eventVersionMillis = Date.now(),
}) {
  const normalizedUid = toSafeUid(uid);
  const normalizedPostId = typeof postId === "string" ? postId.trim() : "";
  const interactionId = typeof eventId === "string"
    ? eventId.trim().replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 140)
    : "";
  if (!normalizedUid || !normalizedPostId || !interactionId ||
      !(ACTION_WEIGHTS[action] || NEGATIVE_ACTION_WEIGHTS[action])) {
    return;
  }

  let didDeactivate = false;
  const ref = interactionRef(normalizedUid, interactionId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = snap.data() || {};
    const existingVersion = Number(existing.eventVersionMillis) || 0;
    if (snap.exists && existingVersion > eventVersionMillis) return;
    if (snap.exists && existing.active === false &&
        existingVersion === eventVersionMillis) {
      return;
    }

    tx.set(ref, {
      postId: normalizedPostId,
      action,
      actionWeight: ACTION_WEIGHTS[action] || NEGATIVE_ACTION_WEIGHTS[action],
      active: false,
      eventVersionMillis,
      createdAtMillis: Number(existing.createdAtMillis) || Date.now(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    didDeactivate = snap.exists && existing.active !== false;
  });

  if (didDeactivate) {
    await rebuildUserInterestVector(normalizedUid, {
      invalidationReason: `${action}_removed`,
    });
  } else {
    await invalidateRecommendationCache(normalizedUid, `${action}_removed`);
  }
}

async function recordNegativeRecommendationInteraction({
  uid, postId, action, eventId, occurredAt, eventVersionMillis = Date.now(),
}) {
  const normalizedUid = toSafeUid(uid);
  const normalizedPostId = typeof postId === "string" ? postId.trim() : "";
  const actionWeight = NEGATIVE_ACTION_WEIGHTS[action];
  if (!normalizedUid || !normalizedPostId || !actionWeight) return;
  const postSnap = await db.collection("posts").doc(normalizedPostId).get();
  if (!postSnap.exists) return;
  const vector = await ensurePostEmbedding(normalizedPostId, postSnap.data() || {});
  if (!vector.length) return;
  const interactionId = String(eventId || `${action}_${normalizedPostId}`)
    .replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 140);
  await interactionRef(normalizedUid, interactionId).set({
    postId: normalizedPostId,
    action,
    actionWeight,
    direction: "negative",
    postVector: vector,
    active: true,
    embeddingModel: EMBEDDING_MODEL,
    vectorDimensions: vector.length,
    eventVersionMillis,
    createdAt: occurredAt || admin.firestore.FieldValue.serverTimestamp(),
    createdAtMillis: toMillis(occurredAt) || Date.now(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await rebuildUserInterestVector(normalizedUid, {
    invalidationReason: action,
  });
}

async function rebuildUserInterestVector(
  uid,
  { invalidationReason = "scheduled_rebuild" } = {}
) {
  const normalizedUid = toSafeUid(uid);
  if (!normalizedUid) return false;

  const interactionsSnap = await db
    .collection("users")
    .doc(normalizedUid)
    .collection("recommendationInteractions")
    .orderBy("createdAtMillis", "desc")
    .limit(INTERACTION_HISTORY_LIMIT)
    .get();

  const nowMillis = Date.now();
  let totalWeight = 0;
  let rebuiltVector = [];
  let effectiveCount = 0;
  let negativeTotalWeight = 0;
  let negativeVector = [];

  for (const doc of interactionsSnap.docs) {
    const interaction = doc.data() || {};
    if (interaction.active === false) continue;
    if ((interaction.embeddingModel || DEFAULT_EMBEDDING_MODEL) !==
        EMBEDDING_MODEL) {
      continue;
    }
    const vector = parseVector(interaction.postVector);
    const actionWeight = Number(interaction.actionWeight) || 0;
    if (vector.length !== EMBEDDING_DIMENSIONS || actionWeight <= 0) continue;

    const occurredAtMillis =
      Number(interaction.createdAtMillis) ||
      toMillis(interaction.createdAt) ||
      nowMillis;
    const decayedWeight =
      actionWeight * exponentialDecay(
        occurredAtMillis,
        nowMillis,
        INTEREST_HALF_LIFE_DAYS
      );
    if (decayedWeight <= 0) continue;

    if (interaction.direction === "negative") {
      const nextWeight = negativeTotalWeight + decayedWeight;
      negativeVector = !negativeVector.length
        ? vector
        : vector.map((value, index) =>
          ((negativeVector[index] * negativeTotalWeight) +
            (value * decayedWeight)) / nextWeight);
      negativeTotalWeight = nextWeight;
      continue;
    }

    if (!rebuiltVector.length || rebuiltVector.length !== vector.length) {
      rebuiltVector = vector;
      totalWeight = decayedWeight;
      effectiveCount += actionWeight;
      continue;
    }

    const nextTotalWeight = totalWeight + decayedWeight;
    rebuiltVector = vector.map((value, index) => {
      return (
        (rebuiltVector[index] * totalWeight) +
        (value * decayedWeight)
      ) / (totalWeight + decayedWeight);
    });
    totalWeight = nextTotalWeight;
    effectiveCount += actionWeight;
  }

  await db.collection("users").doc(normalizedUid).set(
    {
      interestVector: rebuiltVector,
      interestWeight: Math.min(MAX_WEIGHT_CAP, totalWeight),
      effectiveCount,
      negativeInterestVector: negativeVector,
      negativeInterestWeight: Math.min(MAX_WEIGHT_CAP, negativeTotalWeight),
      negativeInterestEmbeddingModel: EMBEDDING_MODEL,
      interestEmbeddingModel: EMBEDDING_MODEL,
      interestVectorDimensions: rebuiltVector.length,
      interestUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      recommendationCacheInvalidatedAt:
        admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  await invalidateRecommendationCache(normalizedUid, invalidationReason);
  return rebuiltVector.length > 0;
}

module.exports = {
  ACTION_WEIGHTS,
  NEGATIVE_ACTION_WEIGHTS,
  CACHE_POST_POOL_SIZE,
  CACHE_TTL_MS,
  CANDIDATE_LIMIT,
  DECAY_FLOOR,
  HALF_LIFE_DAYS,
  INTEREST_HALF_LIFE_DAYS,
  MAX_WEIGHT_CAP,
  MAX_POSTS_PER_AUTHOR_IN_PRIMARY_POOL,
  MIN_SIMILARITY,
  RECOMMENDATION_ALGORITHM_VERSION,
  TRENDING_WINDOW_DAYS,
  buildRecommendationPool,
  bumpRecommendationFeedRevision,
  calculateTrendingScore,
  calculateSeenPenalty,
  cosineSimilarity,
  deactivateRecommendationInteraction,
  diversifyByAuthor,
  ensurePostEmbedding,
  exponentialDecay,
  getOrBuildRecommendationPool,
  hasReusablePostEmbedding,
  invalidateRecommendationCache,
  isEligiblePost,
  isPostEmbeddingCurrent,
  isFrequencyCapped,
  loadHybridCandidatePosts,
  normalizeRatios,
  composeDiversePool,
  parseVector,
  rebuildUserInterestVector,
  recordRecommendationInteraction,
  recordNegativeRecommendationInteraction,
  recommendationCacheRef,
  recommendationFeedStateRef,
  resolveRatios,
  shuffleScoreBands,
  timeDecay,
  toMillis,
  toSafeUid,
};
