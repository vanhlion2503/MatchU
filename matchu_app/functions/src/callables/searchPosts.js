const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db } = require("../shared/firebase");
const { fetchRestrictions, toSafeUid } = require("../recommendation/core");
const { calculatePopularitySignal } = require("../recommendation/retrieval");
const {
  normalizeSearchText,
  scorePostSearchMatch,
  tokenize,
} = require("../search/postSearch");

const MAX_LIMIT = 30;
const MAX_QUERY_LENGTH = 120;
const MAX_QUERY_TERMS = 30;
const INDEX_CANDIDATE_LIMIT = 400;
const FALLBACK_RECENT_LIMIT = 240;
const SEARCH_INDEX_COLLECTION = "postRecommendationIndex";

function isSearchEligible(post) {
  return Boolean(
    post &&
    !post.deletedAt &&
    post.visibility === "public" &&
    (post.moderationStatus || "approved") === "approved" &&
    post.postType !== "repost"
  );
}

async function loadIndexedCandidateIds(field, queryTerms) {
  if (!queryTerms.length) return [];
  try {
    const snapshot = await db
      .collection(SEARCH_INDEX_COLLECTION)
      .where("eligible", "==", true)
      .where(field, "array-contains-any", queryTerms)
      .limit(INDEX_CANDIDATE_LIMIT)
      .select("postId")
      .get();
    return snapshot.docs
      .map((doc) => String(doc.get("postId") || doc.id).trim())
      .filter(Boolean);
  } catch (error) {
    // The recent fallback keeps search available while a new index is deploying.
    console.warn(`searchPosts ${field} lookup unavailable:`, error?.message || error);
    return [];
  }
}

async function loadRecentCandidates() {
  const snapshot = await db
    .collection("posts")
    .where("visibility", "==", "public")
    .where("moderationStatus", "==", "approved")
    .orderBy("createdAt", "desc")
    .limit(FALLBACK_RECENT_LIMIT)
    .get();
  return snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() || {} }));
}

async function loadPostsByIds(postIds) {
  const result = [];
  for (let offset = 0; offset < postIds.length; offset += 100) {
    const ids = postIds.slice(offset, offset + 100);
    const snapshots = await db.getAll(
      ...ids.map((postId) => db.collection("posts").doc(postId))
    );
    for (const snapshot of snapshots) {
      if (snapshot.exists) {
        result.push({ id: snapshot.id, data: snapshot.data() || {} });
      }
    }
  }
  return result;
}

function createdAtMillis(post) {
  return post?.createdAt?.toMillis?.() || 0;
}

const searchPosts = onCall(
  { timeoutSeconds: 30, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const uid = toSafeUid(request.auth.uid);
    const rawQuery = String(request.data?.query || "").trim();
    const normalizedQuery = normalizeSearchText(rawQuery);
    if (!normalizedQuery) {
      throw new HttpsError("invalid-argument", "Search query is required.");
    }
    if (rawQuery.length > MAX_QUERY_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `Search query cannot exceed ${MAX_QUERY_LENGTH} characters.`
      );
    }

    const limit = Math.min(Math.max(Number(request.data?.limit) || 20, 1), MAX_LIMIT);
    const offset = Math.max(Number(request.data?.offset) || 0, 0);
    const queryTerms = Array.from(new Set(tokenize(normalizedQuery)))
      .slice(0, MAX_QUERY_TERMS);
    const prefixQueryTerms = queryTerms.filter((term) => term.length >= 4);

    try {
      const [exactIds, prefixIds, restrictions] = await Promise.all([
        loadIndexedCandidateIds("searchExactTerms", queryTerms),
        loadIndexedCandidateIds("searchTerms", prefixQueryTerms),
        fetchRestrictions(uid),
      ]);
      const indexedIds = Array.from(new Set([...exactIds, ...prefixIds]));
      const [indexedCandidates, recentCandidates] = await Promise.all([
        loadPostsByIds(indexedIds),
        // Existing posts remain searchable while the scheduled index backfill
        // is catching up, without charging this scan on normal indexed calls.
        indexedIds.length ? Promise.resolve([]) : loadRecentCandidates(),
      ]);
      const candidateById = new Map();
      for (const candidate of [...indexedCandidates, ...recentCandidates]) {
        candidateById.set(candidate.id, candidate);
      }

      const ranked = [];
      for (const candidate of candidateById.values()) {
        const post = candidate.data;
        if (!isSearchEligible(post)) continue;
        if (restrictions.hiddenPostIds.has(candidate.id)) continue;
        if (restrictions.restrictedAuthorIds.has(String(post.authorId || "").trim())) {
          continue;
        }

        const match = scorePostSearchMatch(post, rawQuery);
        if (!match) continue;
        ranked.push({
          postId: candidate.id,
          matchType: match.matchType,
          score: match.score,
          matchQuality: match.matchQuality,
          popularity: calculatePopularitySignal(post),
          createdAtMillis: createdAtMillis(post),
        });
      }

      ranked.sort((a, b) =>
        (b.score - a.score) ||
        (b.matchQuality - a.matchQuality) ||
        (b.popularity - a.popularity) ||
        (b.createdAtMillis - a.createdAtMillis) ||
        a.postId.localeCompare(b.postId)
      );

      const page = ranked.slice(offset, offset + limit);
      return {
        query: rawQuery,
        normalizedQuery,
        items: page.map(({ postId, matchType, score }) => ({
          postId,
          matchType,
          score,
        })),
        limit,
        offset,
        hasMore: offset + limit < ranked.length,
        totalMatched: ranked.length,
      };
    } catch (error) {
      console.error("searchPosts failed:", {
        uid,
        query: normalizedQuery,
        error: error?.message || String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Unable to search posts.");
    }
  }
);

module.exports = { searchPosts };
