"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  ACTION_WEIGHTS,
  NEGATIVE_ACTION_WEIGHTS,
  calculateDiscoveryScore,
  calculateTrendingScore,
  calculateSeenPenalty,
  composeDiversePool,
  composeNoveltyAwarePool,
  cosineSimilarity,
  diversifyByAuthor,
  isPostEmbeddingCurrent,
  isRecommendationSessionReusable,
  isFrequencyCapped,
  interactionCooldownMs,
  noveltySuppressionReason,
  parseVector,
  resolveRatios,
  resolveDiscoveryWeight,
  resolveCompositionTargets,
} = require("../src/recommendation/core");
const { calculatePopularitySignal } = require("../src/recommendation/retrieval");
const { normalizeTopicIds } = require("../src/recommendation/topicTaxonomy");
const {
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
  embeddingSignatureForPost,
} = require("../src/recommendation/embedding");
const {
  buildEmbeddingSearchKey,
  recentTrendDayKeys,
  trendDayKey,
} = require("../src/recommendation/retrieval");

test("parseVector rejects partially corrupt data", () => {
  assert.deepEqual(parseVector([0.1, 0.2]), [0.1, 0.2]);
  assert.deepEqual(parseVector([0.1, Number.NaN]), []);
  assert.deepEqual(parseVector([0.1, "0.2"]), []);
});

test("cosine similarity rejects mismatched dimensions", () => {
  assert.equal(cosineSimilarity([1, 0], [1, 0]), 1);
  assert.equal(cosineSimilarity([1, 0], [0, 1]), 0);
  assert.equal(cosineSimilarity([1], [1, 0]), 0);
});

test("personalization ratios stay normalized without following", () => {
  const interestVector = Array(EMBEDDING_DIMENSIONS).fill(0.1);
  const ratios = resolveRatios({
    effectiveCount: 12,
    interestVector,
    interestEmbeddingModel: EMBEDDING_MODEL,
  }, false);

  assert.ok(Math.abs(ratios.content + ratios.trending - 1) < 1e-12);
  assert.equal(ratios.following, 0);
});

test("fresh zero-engagement posts retain a discovery score", () => {
  const now = Date.now();
  const score = calculateTrendingScore({
    createdAt: now,
    stats: {},
    trendScore: 0,
    trendBucket: 0,
  }, now);
  assert.ok(score > 0);
});

test("cold-start discovery keeps eligible posts beyond the trending window", () => {
  const now = Date.now();
  const eightDaysOld = calculateDiscoveryScore({
    createdAt: now - (8 * 86400000),
    stats: {},
  }, now);
  const sixtyDaysOld = calculateDiscoveryScore({
    createdAt: now - (60 * 86400000),
    stats: {},
  }, now);

  assert.ok(eightDaysOld > 0);
  assert.ok(sixtyDaysOld > 0);
  assert.ok(eightDaysOld > sixtyDaysOld);
  assert.ok(resolveDiscoveryWeight("cold_start_trending") >
    resolveDiscoveryWeight("personalized"));
});

test("embedding metadata detects content and model changes", () => {
  const post = { content: "Flutter Firebase", tags: ["dart"] };
  const signature = embeddingSignatureForPost(post);
  const current = {
    ...post,
    contentVector: Array(EMBEDDING_DIMENSIONS).fill(0.01),
    contentEmbeddingModel: EMBEDDING_MODEL,
    contentEmbeddingSignature: signature,
    contentVectorDimensions: EMBEDDING_DIMENSIONS,
    contentVectorSearchKey: buildEmbeddingSearchKey(
      signature,
      EMBEDDING_DIMENSIONS
    ),
  };

  assert.equal(isPostEmbeddingCurrent(current), true);
  assert.equal(isPostEmbeddingCurrent({ ...current, content: "AI mới" }), false);
  assert.equal(isPostEmbeddingCurrent({
    ...current,
    contentEmbeddingModel: "old-model",
  }), false);
});

test("retrieval index uses stable UTC day keys", () => {
  const now = Date.UTC(2026, 6, 11, 12, 0, 0);
  assert.equal(trendDayKey(now), "20260711");
  assert.deepEqual(recentTrendDayKeys(now, 1), ["20260711", "20260710"]);
});

test("author diversity preserves pool capacity", () => {
  const ranked = [
    ...Array.from({ length: 5 }, (_, index) => ({
      postId: `a-${index}`,
      authorId: "a",
    })),
    ...Array.from({ length: 3 }, (_, index) => ({
      postId: `b-${index}`,
      authorId: "b",
    })),
  ];

  const selected = diversifyByAuthor(ranked, 6);
  assert.equal(selected.length, 6);
  assert.equal(selected.filter((item) => item.authorId === "b").length, 3);
});

test("taxonomy maps aliases to stable topic IDs", () => {
  assert.deepEqual(
    normalizeTopicIds([" Flutter ", "flutter-dev", "Lập trình Flutter", "AI"]),
    ["flutter", "ai"],
  );
});

test("save count contributes to popularity with the recommendation weight", () => {
  const score = calculatePopularitySignal({ stats: { saveCount: 2 } });
  assert.ok(Math.abs(score - Math.log1p(2.6)) < 1e-12);
});

test("implicit and negative feedback weights remain intentionally bounded", () => {
  assert.ok(ACTION_WEIGHTS.dwell < ACTION_WEIGHTS.like);
  assert.ok(NEGATIVE_ACTION_WEIGHTS.report > NEGATIVE_ACTION_WEIGHTS.hide_post);
});

test("seen penalty is capped and 24-hour frequency cap starts at three", () => {
  const now = Date.now();
  const impression = {
    lastSeenAt: now - 1000,
    lastDwellMs: 8000,
    frequencyWindowStartedAt: now - 60000,
    impressionCount24h: 12,
  };
  assert.ok(Math.abs(calculateSeenPenalty(impression, now) - 0.40) < 1e-12);
  assert.equal(isFrequencyCapped(impression, now), true);
  assert.equal(isFrequencyCapped({ ...impression, impressionCount24h: 2 }, now), false);
});

test("recommendation session expires when user cache is invalidated", () => {
  const now = Date.now();
  const session = {
    postIds: ["post-1"],
    feedRevision: 5,
    createdAtMillis: now - 1000,
    expiresAtMillis: now + 60000,
  };
  assert.equal(isRecommendationSessionReusable(session, now, now - 2000, 5), true);
  assert.equal(isRecommendationSessionReusable(session, now, now, 5), false);
  assert.equal(isRecommendationSessionReusable(session, now, 0, 6), false);
  assert.equal(isRecommendationSessionReusable(session, now + 60001, 0, 5), false);
});

test("composition targets follow scoring ratios while reserving exploration", () => {
  assert.deepEqual(resolveCompositionTargets(20, {
    content: 0.7,
    trending: 0.2,
    following: 0.1,
    label: "personalized",
  }), { content: 13, trending: 4, following: 1, exploration: 2 });
  assert.deepEqual(resolveCompositionTargets(20, {
    content: 0,
    trending: 0.6,
    following: 0.4,
    label: "cold_start",
  }), { content: 0, trending: 10, following: 6, exploration: 4 });
});

test("diverse pool reserves exploration and following slots per page", () => {
  const ranked = Array.from({ length: 40 }, (_, index) => ({
    postId: `post-${index}`,
    contentBasedScore: index < 30 ? 1 : 0,
    rawTrendingScore: index < 35 ? 1 : 0,
    followingBoost: index === 39 ? 1 : 0,
  }));
  const selected = composeDiversePool(ranked, 20, "stable-seed", {
    content: 0.7,
    trending: 0.2,
    following: 0.1,
    label: "personalized",
  });
  assert.equal(selected.length, 20);
  assert.ok(selected.some((item) => item.postId === "post-39"));
});

test("novelty suppression applies refresh, view and explicit-action cooldowns", () => {
  const now = Date.now();
  assert.equal(noveltySuppressionReason({
    postId: "refresh-post",
    excludedPostIds: new Set(["refresh-post"]),
    nowMillis: now,
  }), "refresh_history");
  assert.equal(noveltySuppressionReason({
    postId: "liked-post",
    interaction: {
      action: "like",
      cooldownUntilMillis: now + interactionCooldownMs("like"),
    },
    nowMillis: now,
  }), "recent_like");
  assert.equal(noveltySuppressionReason({
    postId: "viewed-post",
    impression: { lastSeenAt: now - 1000, lastDwellMs: 6000 },
    nowMillis: now,
  }), "recent_long_view");
  assert.equal(noveltySuppressionReason({
    postId: "expired-post",
    impression: { lastSeenAt: now - (13 * 60 * 60 * 1000), lastDwellMs: 6000 },
    nowMillis: now,
  }), null);
  assert.equal(interactionCooldownMs("save"), 48 * 60 * 60 * 1000);
});

test("cold-start composition fills a page when only one post is trending", () => {
  const ranked = Array.from({ length: 40 }, (_, index) => ({
    postId: `post-${index}`,
    contentBasedScore: 0,
    rawTrendingScore: index === 0 ? 1 : 0,
    followingBoost: 0,
  }));
  const selected = composeDiversePool(ranked, 20, "cold-start", {
    content: 0,
    trending: 1,
    following: 0,
    label: "cold_start_trending",
  });

  assert.equal(selected.length, 20);
  assert.ok(selected.some((item) => item.postId === "post-0"));
});

test("novelty-aware composition never explores fallback while unseen is enough", () => {
  const base = {
    contentBasedScore: 1,
    rawTrendingScore: 1,
    followingBoost: 0,
    finalScore: 1,
  };
  const unseenRanked = Array.from({ length: 30 }, (_, index) => ({
    ...base,
    postId: `unseen-${index}`,
    authorId: `author-${index}`,
  }));
  const seenFallback = Array.from({ length: 10 }, (_, index) => ({
    ...base,
    postId: `seen-${index}`,
    authorId: `seen-author-${index}`,
  }));
  const result = composeNoveltyAwarePool({
    unseenRanked,
    seenFallback,
    limit: 20,
    seed: "novelty",
    ratios: {
      content: 0.7,
      trending: 0.3,
      following: 0,
      label: "personalized",
    },
  });

  assert.equal(result.pool.length, 20);
  assert.equal(result.fallbackUsedCount, 0);
  assert.ok(result.pool.every((item) => item.postId.startsWith("unseen-")));
});

test("novelty-aware composition uses fallback only to keep a sparse feed full", () => {
  const item = (postId) => ({
    postId,
    authorId: postId,
    contentBasedScore: 0,
    rawTrendingScore: 1,
    followingBoost: 0,
    finalScore: 1,
  });
  const result = composeNoveltyAwarePool({
    unseenRanked: Array.from({ length: 6 }, (_, index) => item(`new-${index}`)),
    seenFallback: Array.from({ length: 10 }, (_, index) => item(`old-${index}`)),
    limit: 10,
    seed: "sparse",
    ratios: {
      content: 0,
      trending: 1,
      following: 0,
      label: "cold_start_trending",
    },
  });

  assert.equal(result.pool.length, 10);
  assert.equal(result.fallbackUsedCount, 4);
  assert.ok(result.pool.slice(0, 6).every((item) => item.postId.startsWith("new-")));
});
