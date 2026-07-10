"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  calculateTrendingScore,
  cosineSimilarity,
  diversifyByAuthor,
  exponentialDecay,
  isPostEmbeddingCurrent,
  normalizeRatios,
  parseVector,
  resolveRatios,
} = require("../src/recommendation/core");
const {
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
  embeddingSignatureForPost,
} = require("../src/recommendation/embedding");
const {
  buildEmbeddingSearchKey,
  calculatePopularitySignal,
  recentTrendDayKeys,
  trendDayKey,
} = require("../src/recommendation/retrieval");

test("parseVector rejects a partially corrupt vector", () => {
  assert.deepEqual(parseVector([0.1, 0.2]), [0.1, 0.2]);
  assert.deepEqual(parseVector([0.1, Number.NaN]), []);
  assert.deepEqual(parseVector([0.1, "0.2"]), []);
});

test("cosine similarity is stable for normalized and invalid dimensions", () => {
  assert.equal(cosineSimilarity([1, 0], [1, 0]), 1);
  assert.equal(cosineSimilarity([1, 0], [0, 1]), 0);
  assert.equal(cosineSimilarity([1], [1, 0]), 0);
});

test("ratios always sum to one when following is unavailable", () => {
  const interestVector = Array(EMBEDDING_DIMENSIONS).fill(0.1);
  const exploration = resolveRatios({
    effectiveCount: 5,
    interestVector,
    interestEmbeddingModel: EMBEDDING_MODEL,
  }, false);
  const personalized = resolveRatios({
    effectiveCount: 12,
    interestVector,
    interestEmbeddingModel: EMBEDDING_MODEL,
  }, false);

  for (const ratios of [exploration, personalized]) {
    const total = ratios.content + ratios.trending + ratios.following;
    assert.ok(Math.abs(total - 1) < 1e-12);
    assert.equal(ratios.following, 0);
  }

  assert.deepEqual(normalizeRatios({
    content: 0,
    trending: 0,
    following: 0,
    label: "empty",
  }), {
    content: 0,
    trending: 0,
    following: 0,
    label: "empty",
  });
});

test("a fresh zero-engagement post still receives a discovery score", () => {
  const now = Date.now();
  const freshScore = calculateTrendingScore({
    createdAt: now,
    stats: {},
    trendScore: 0,
    trendBucket: 0,
  }, now);
  const popularScore = calculateTrendingScore({
    createdAt: now,
    stats: { likeCount: 100, commentCount: 20, shareCount: 10 },
    trendScore: 0,
    trendBucket: 0,
  }, now);

  assert.ok(freshScore > 0);
  assert.ok(popularScore > freshScore);
  assert.ok(exponentialDecay(now - (3 * 86400000), now) > 0.49);
});

test("embedding metadata invalidates edited or model-mismatched content", () => {
  const post = { content: "Flutter Firebase", tags: ["dart"] };
  const current = {
    ...post,
    contentVector: Array.from(
      { length: EMBEDDING_DIMENSIONS },
      (_, index) => index / EMBEDDING_DIMENSIONS
    ),
    contentEmbeddingModel: EMBEDDING_MODEL,
    contentEmbeddingSignature: embeddingSignatureForPost(post),
    contentVectorDimensions: EMBEDDING_DIMENSIONS,
  };
  current.contentVectorSearchKey = buildEmbeddingSearchKey(
    current.contentEmbeddingSignature,
    EMBEDDING_DIMENSIONS
  );

  assert.equal(isPostEmbeddingCurrent(current), true);
  assert.equal(isPostEmbeddingCurrent({ ...current, content: "AI mới" }), false);
  assert.equal(isPostEmbeddingCurrent({
    ...current,
    contentEmbeddingModel: "old-model",
  }), false);
  assert.equal(isPostEmbeddingCurrent({
    ...current,
    contentVectorDimensions: 3,
  }), false);
});

test("retrieval index uses stable UTC day keys and log-scaled popularity", () => {
  const now = Date.UTC(2026, 6, 11, 12, 0, 0);
  assert.equal(trendDayKey(now), "20260711");
  const keys = recentTrendDayKeys(now, 7);
  assert.equal(keys.length, 8);
  assert.equal(keys[0], "20260711");
  assert.equal(keys.at(-1), "20260704");
  assert.equal(calculatePopularitySignal({ stats: {} }), 0);
  assert.ok(calculatePopularitySignal({
    stats: { likeCount: 10, commentCount: 2, shareCount: 1 },
  }) > 0);
});

test("author diversity defers repeated posts without dropping pool capacity", () => {
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
  assert.equal(selected.slice(0, 6).filter((item) => item.authorId === "a").length, 3);
  assert.equal(selected.filter((item) => item.authorId === "b").length, 3);
});
