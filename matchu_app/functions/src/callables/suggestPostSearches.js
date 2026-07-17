const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db } = require("../shared/firebase");
const { fetchRestrictions, toSafeUid } = require("../recommendation/core");
const { normalizeSearchText, tokenize } = require("../search/postSearch");
const {
  buildPostSearchSuggestions,
} = require("../search/postSearchSuggestions");

const SEARCH_INDEX_COLLECTION = "postRecommendationIndex";
const MAX_QUERY_LENGTH = 120;
const MIN_INDEX_PREFIX_LENGTH = 4;
const MAX_LIMIT = 10;
const CANDIDATE_LIMIT = 60;

async function loadPostsByIds(postIds, popularityById) {
  const posts = [];
  for (let offset = 0; offset < postIds.length; offset += 100) {
    const ids = postIds.slice(offset, offset + 100);
    const snapshots = await db.getAll(
      ...ids.map((postId) => db.collection("posts").doc(postId))
    );
    for (const snapshot of snapshots) {
      if (!snapshot.exists) continue;
      posts.push({
        postId: snapshot.id,
        data: snapshot.data() || {},
        popularity: popularityById.get(snapshot.id) || 0,
      });
    }
  }
  return posts;
}

function isSearchEligible(post) {
  return Boolean(
    post &&
    !post.deletedAt &&
    post.visibility === "public" &&
    (post.moderationStatus || "approved") === "approved" &&
    post.postType !== "repost"
  );
}

const suggestPostSearches = onCall(
  { timeoutSeconds: 15, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const uid = toSafeUid(request.auth.uid);
    const rawQuery = String(request.data?.query || "").trim();
    const normalizedQuery = normalizeSearchText(rawQuery);
    if (normalizedQuery.length < 2 || rawQuery.length > MAX_QUERY_LENGTH) {
      throw new HttpsError("invalid-argument", "Invalid suggestion query.");
    }

    const limit = Math.min(
      Math.max(Number(request.data?.limit) || 8, 1),
      MAX_LIMIT
    );
    // Firestore's array index contains prefixes from four characters. For a
    // short last word, use an earlier meaningful word as the candidate anchor.
    const anchor = tokenize(normalizedQuery)
      .reverse()
      .find((term) => term.length >= MIN_INDEX_PREFIX_LENGTH);
    if (!anchor) {
      return { query: rawQuery, suggestions: [] };
    }

    try {
      const [snapshot, restrictions] = await Promise.all([
        db
          .collection(SEARCH_INDEX_COLLECTION)
          .where("eligible", "==", true)
          .where("searchTerms", "array-contains", anchor)
          .limit(CANDIDATE_LIMIT)
          .select("postId", "authorId", "popularityScore")
          .get(),
        fetchRestrictions(uid),
      ]);

      const popularityById = new Map();
      const postIds = [];
      for (const doc of snapshot.docs) {
        const postId = String(doc.get("postId") || doc.id).trim();
        const authorId = String(doc.get("authorId") || "").trim();
        if (!postId || restrictions.hiddenPostIds.has(postId)) continue;
        if (restrictions.restrictedAuthorIds.has(authorId)) continue;
        postIds.push(postId);
        popularityById.set(postId, Number(doc.get("popularityScore")) || 0);
      }

      const posts = (await loadPostsByIds(postIds, popularityById)).filter(
        (item) =>
          isSearchEligible(item.data) &&
          !restrictions.hiddenPostIds.has(item.postId) &&
          !restrictions.restrictedAuthorIds.has(
            String(item.data.authorId || "").trim()
          )
      );
      return {
        query: rawQuery,
        suggestions: buildPostSearchSuggestions(posts, rawQuery, limit),
      };
    } catch (error) {
      console.error("suggestPostSearches failed:", {
        uid,
        query: normalizedQuery,
        error: error?.message || String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Unable to suggest post searches.");
    }
  }
);

module.exports = { suggestPostSearches };
