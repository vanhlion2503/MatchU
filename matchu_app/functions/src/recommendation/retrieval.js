const { admin, db } = require("../shared/firebase");
const {
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
} = require("./embedding");

const RECOMMENDATION_INDEX_COLLECTION = "postRecommendationIndex";
const VECTOR_FIELD = "embedding";
const VECTOR_DISTANCE_FIELD = "vectorDistance";
const VECTOR_CANDIDATE_LIMIT = 160;
const TRENDING_CANDIDATE_LIMIT = 120;
const RECENT_CANDIDATE_LIMIT = 180;
const FOLLOWING_CANDIDATE_LIMIT_PER_CHUNK = 24;
const MAX_FOLLOWING_AUTHORS_FOR_CANDIDATES = 300;
const FIRESTORE_IN_LIMIT = 30;

function recommendationIndexRef(postId) {
  return db.collection(RECOMMENDATION_INDEX_COLLECTION).doc(postId);
}

function toMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  return null;
}

function trendDayKey(value) {
  const millis = toMillis(value);
  if (!millis) return "";
  const date = new Date(millis);
  const year = String(date.getUTCFullYear());
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}${month}${day}`;
}

function recentTrendDayKeys(
  nowMillis = Date.now(),
  windowDays = 7
) {
  const keys = [];
  for (let offset = 0; offset <= windowDays; offset += 1) {
    keys.push(trendDayKey(nowMillis - (offset * 86400000)));
  }
  return keys.filter(Boolean);
}

function calculatePopularitySignal(post) {
  const stats = post?.stats || {};
  const engagement =
    ((Number(stats.likeCount) || 0) * 1.0) +
    ((Number(stats.commentCount) || 0) * 0.8) +
    ((Number(stats.saveCount) || 0) * 1.3) +
    ((Number(stats.shareCount) || 0) * 1.5);
  const popularity = Math.max(
    0,
    engagement +
      (Number(post?.trendScore) || 0) +
      ((Number(post?.trendBucket) || 0) * 0.25)
  );
  return Math.log1p(popularity);
}

function buildEmbeddingSearchKey(signature, dimensions = EMBEDDING_DIMENSIONS) {
  return `${EMBEDDING_MODEL}:${dimensions}:${signature}`;
}

function buildRecommendationIndexMetadata(postId, post) {
  return {
    postId,
    authorId: typeof post?.authorId === "string" ? post.authorId.trim() : "",
    referenceAuthorId:
      typeof post?.referencePost?.authorId === "string"
        ? post.referencePost.authorId.trim()
        : "",
    createdAt: post?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    trendDayKey: trendDayKey(post?.createdAt),
    popularityScore: calculatePopularitySignal(post),
    eligible: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function isRecommendationIndexEligible(post) {
  return Boolean(
    post &&
    !post.deletedAt &&
    post.visibility === "public" &&
    (post.moderationStatus || "approved") === "approved" &&
    post.postType !== "repost"
  );
}

async function syncRecommendationIndexMetadata(
  postId,
  post,
  eligible,
  { eventVersionMillis = Date.now(), reconcileSource = false } = {}
) {
  const normalizedPostId = typeof postId === "string" ? postId.trim() : "";
  if (!normalizedPostId) return;
  const ref = recommendationIndexRef(normalizedPostId);
  const postRef = db.collection("posts").doc(normalizedPostId);
  await db.runTransaction(async (tx) => {
    const [indexSnap, sourceSnap] = await Promise.all([
      tx.get(ref),
      reconcileSource ? tx.get(postRef) : Promise.resolve(null),
    ]);
    const existingVersion = Number(indexSnap.data()?.sourceVersionMillis) || 0;
    let effectivePost = post || {};
    let effectiveEligible = eligible === true;
    let effectiveVersion = eventVersionMillis;
    if (reconcileSource) {
      effectivePost = sourceSnap?.exists ? sourceSnap.data() || {} : {};
      effectiveEligible = sourceSnap?.exists &&
        isRecommendationIndexEligible(effectivePost);
      effectiveVersion =
        toMillis(effectivePost.updatedAt) ||
        toMillis(effectivePost.createdAt) ||
        eventVersionMillis;
    }
    if (existingVersion > effectiveVersion) return;

    if (effectiveEligible) {
      tx.set(ref, {
        ...buildRecommendationIndexMetadata(normalizedPostId, effectivePost),
        sourceVersionMillis: effectiveVersion,
      }, { merge: true });
      return;
    }

    tx.set(ref, {
      postId: normalizedPostId,
      eligible: false,
      sourceVersionMillis: effectiveVersion,
      embedding: admin.firestore.FieldValue.delete(),
      embeddingModel: admin.firestore.FieldValue.delete(),
      embeddingSignature: admin.firestore.FieldValue.delete(),
      embeddingDimensions: admin.firestore.FieldValue.delete(),
      embeddingUpdatedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

async function loadVectorCandidateMatches(
  userVector,
  { minSimilarity = 0.7, limit = VECTOR_CANDIDATE_LIMIT } = {}
) {
  if (!Array.isArray(userVector) || userVector.length !== EMBEDDING_DIMENSIONS) {
    return [];
  }

  const query = db
    .collection(RECOMMENDATION_INDEX_COLLECTION)
    .where("eligible", "==", true)
    .where("embeddingModel", "==", EMBEDDING_MODEL)
    .select("postId", VECTOR_DISTANCE_FIELD)
    .findNearest({
      vectorField: VECTOR_FIELD,
      queryVector: userVector,
      limit,
      distanceMeasure: "COSINE",
      distanceResultField: VECTOR_DISTANCE_FIELD,
      distanceThreshold: Math.max(0, Math.min(2, 1 - minSimilarity)),
    });
  const snapshot = await query.get();
  return snapshot.docs
    .map((doc) => {
      const distance = Number(doc.get(VECTOR_DISTANCE_FIELD));
      const postId = String(doc.get("postId") || doc.id).trim();
      if (!postId || !Number.isFinite(distance)) return null;
      return {
        postId,
        similarity: Math.max(-1, Math.min(1, 1 - distance)),
      };
    })
    .filter(Boolean);
}

async function loadTrendingCandidateIds(
  nowMillis = Date.now(),
  limit = TRENDING_CANDIDATE_LIMIT
) {
  const dayKeys = recentTrendDayKeys(nowMillis);
  const snapshot = await db
    .collection(RECOMMENDATION_INDEX_COLLECTION)
    .where("eligible", "==", true)
    .where("trendDayKey", "in", dayKeys)
    .orderBy("popularityScore", "desc")
    .limit(limit)
    .select("postId")
    .get();
  return snapshot.docs
    .map((doc) => String(doc.get("postId") || doc.id).trim())
    .filter(Boolean);
}

async function loadRecentCandidates(limit = RECENT_CANDIDATE_LIMIT) {
  const snapshot = await db
    .collection("posts")
    .where("visibility", "==", "public")
    .where("moderationStatus", "==", "approved")
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return snapshot.docs.map((doc) => ({
    id: doc.id,
    data: doc.data() || {},
  }));
}

async function loadFollowingCandidates(followingIds) {
  const normalizedIds = Array.from(followingIds || [])
    .map((id) => typeof id === "string" ? id.trim() : "")
    .filter(Boolean)
    .slice(-MAX_FOLLOWING_AUTHORS_FOR_CANDIDATES);
  if (!normalizedIds.length) return [];

  const queries = [];
  for (let offset = 0; offset < normalizedIds.length; offset += FIRESTORE_IN_LIMIT) {
    const chunk = normalizedIds.slice(offset, offset + FIRESTORE_IN_LIMIT);
    queries.push(
      db.collection("posts")
        .where("authorId", "in", chunk)
        .where("visibility", "==", "public")
        .orderBy("createdAt", "desc")
        .limit(FOLLOWING_CANDIDATE_LIMIT_PER_CHUNK)
        .get()
    );
  }

  const snapshots = await Promise.all(queries);
  return snapshots.flatMap((snapshot) => snapshot.docs.map((doc) => ({
    id: doc.id,
    data: doc.data() || {},
  })));
}

async function loadPostsByIds(postIds) {
  const normalizedIds = Array.from(new Set(postIds || []))
    .map((id) => typeof id === "string" ? id.trim() : "")
    .filter(Boolean);
  const result = [];
  for (let offset = 0; offset < normalizedIds.length; offset += 100) {
    const chunk = normalizedIds.slice(offset, offset + 100);
    const snapshots = await db.getAll(
      ...chunk.map((postId) => db.collection("posts").doc(postId))
    );
    for (const snapshot of snapshots) {
      if (!snapshot.exists) continue;
      result.push({ id: snapshot.id, data: snapshot.data() || {} });
    }
  }
  return result;
}

module.exports = {
  FIRESTORE_IN_LIMIT,
  FOLLOWING_CANDIDATE_LIMIT_PER_CHUNK,
  MAX_FOLLOWING_AUTHORS_FOR_CANDIDATES,
  RECENT_CANDIDATE_LIMIT,
  RECOMMENDATION_INDEX_COLLECTION,
  TRENDING_CANDIDATE_LIMIT,
  VECTOR_CANDIDATE_LIMIT,
  VECTOR_DISTANCE_FIELD,
  VECTOR_FIELD,
  buildEmbeddingSearchKey,
  buildRecommendationIndexMetadata,
  calculatePopularitySignal,
  loadFollowingCandidates,
  loadPostsByIds,
  loadRecentCandidates,
  loadTrendingCandidateIds,
  loadVectorCandidateMatches,
  isRecommendationIndexEligible,
  recentTrendDayKeys,
  recommendationIndexRef,
  syncRecommendationIndexMetadata,
  trendDayKey,
};
