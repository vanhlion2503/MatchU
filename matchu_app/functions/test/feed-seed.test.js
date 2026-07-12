"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const { CONTENT_BY_TOPIC, TOPICS } = require("../scripts/feed-seed/content");
const {
  buildInteractions,
  buildPosts,
  parseRatios,
  assertSafety,
  validateOptions,
} = require("../scripts/feed-seed/seed");

function options(overrides = {}) {
  return {
    projectId: "matchu-feed-test",
    seedBatchId: "unit-feed-001",
    target: "emulator",
    dryRun: true,
    deleteBatch: false,
    count: 160,
    authorCount: 16,
    interactionActorCount: 8,
    maxAgeDays: 120,
    topics: [...TOPICS],
    ratios: parseRatios("text=1,image=0,video=0"),
    mediaConfigPath: "",
    authorSource: "seed",
    createSeedUsers: true,
    includeInteractions: true,
    includeModerationTestData: true,
    includeReports: true,
    includeRestrictions: true,
    includeShares: true,
    generateEmbeddings: false,
    ...overrides,
  };
}

function users(count, prefix) {
  return Array.from({ length: count }, (_, index) => ({
    id: `${prefix}_${index + 1}`,
    name: `Người dùng ${index + 1}`,
    nickname: `${prefix}${index + 1}`,
    avatar: "",
    isVerified: false,
    isSeedData: true,
  }));
}

test("content catalog has at least three distinct production-sized variants per topic", () => {
  assert.ok(TOPICS.length >= 40);
  for (const topic of TOPICS) {
    const variants = CONTENT_BY_TOPIC[topic];
    assert.ok(variants.length >= 3, topic);
    assert.equal(new Set(variants).size, variants.length, topic);
    for (const content of variants) {
      assert.ok(content.length > 0, topic);
      assert.ok(content.length <= 300, `${topic}: ${content.length}`);
    }
  }
});

test("post builder matches schema, topic coverage, moderation and author bounds", () => {
  const config = options();
  validateOptions(config);
  const authors = users(config.authorCount, "author");
  const posts = buildPosts(config, authors, {
    imageUrls: [],
    videoUrls: [],
    videoThumbnailUrls: [],
  });
  assert.equal(posts.length, config.count);
  const authorCounts = new Map();
  const topicVariants = new Map();
  const statuses = new Set();
  for (const post of posts) {
    const data = post.data;
    for (const key of [
      "postId",
      "authorId",
      "postType",
      "content",
      "media",
      "tags",
      "visibility",
      "isPublic",
      "moderationStatus",
      "stats",
      "trendScore",
      "trendBucket",
      "author",
      "createdAt",
      "updatedAt",
    ]) {
      assert.ok(Object.hasOwn(data, key), `${post.id} missing ${key}`);
    }
    assert.equal(data.isPublic, data.visibility === "public");
    assert.ok(data.content.length <= 300);
    authorCounts.set(data.authorId, (authorCounts.get(data.authorId) || 0) + 1);
    if (!topicVariants.has(post.topic))
      topicVariants.set(post.topic, new Set());
    if (data.postType === "post")
      topicVariants.get(post.topic).add(data.content);
    statuses.add(data.moderationStatus);
  }
  for (const count of authorCounts.values())
    assert.ok(count >= 3 && count <= 15);
  for (const topic of TOPICS)
    assert.ok(topicVariants.get(topic).size >= 3, topic);
  assert.ok(statuses.has("approved"));
  assert.ok(statuses.has("pending_moderation"));
  assert.ok(statuses.has("rejected"));
  assert.ok(statuses.has("review_required"));
});

test("interaction documents are unique and post counters are synchronized", () => {
  const config = options();
  const posts = buildPosts(config, users(config.authorCount, "author"), {
    imageUrls: [],
    videoUrls: [],
    videoThumbnailUrls: [],
  });
  const interactions = buildInteractions(
    config,
    posts,
    users(config.interactionActorCount, "actor"),
  );
  const paths = interactions.map((item) => `${item.collection}/${item.id}`);
  assert.equal(new Set(paths).size, paths.length);
  for (const post of posts) {
    const likes = interactions.filter(
      (item) =>
        item.kind === "like" && item.collection === `posts/${post.id}/likes`,
    ).length;
    const comments = interactions.filter(
      (item) =>
        item.kind === "comment" &&
        item.collection === `posts/${post.id}/comments`,
    ).length;
    const saves = interactions.filter(
      (item) => item.kind === "savedPost" && item.id === post.id,
    ).length;
    assert.equal(post.data.stats.likeCount, likes, `${post.id} likes`);
    assert.equal(post.data.stats.commentCount, comments, `${post.id} comments`);
    assert.equal(post.data.stats.saveCount, saves, `${post.id} saves`);
  }
});

test("configured media produces media-only, single-image and multi-image cases", () => {
  const config = options({
    ratios: parseRatios("text=0,image=1,video=0"),
    includeInteractions: false,
  });
  const posts = buildPosts(config, users(config.authorCount, "author"), {
    imageUrls: [
      "https://media.test/one.jpg",
      "https://media.test/two.jpg",
      "https://media.test/three.jpg",
    ],
    videoUrls: [],
    videoThumbnailUrls: [],
  });
  assert.ok(posts.some((post) => post.data.media.length === 1));
  assert.ok(posts.some((post) => post.data.media.length > 1));
  assert.ok(
    posts.some(
      (post) => post.data.media.length > 0 && post.data.content.length === 0,
    ),
  );
  assert.ok(
    posts.some(
      (post) => post.data.media.length > 0 && post.data.content.length > 0,
    ),
  );
});

test("safety guard refuses missing confirmation and the repository production project", () => {
  const original = {
    allow: process.env.ALLOW_FIRESTORE_SEED,
    allowProduction: process.env.ALLOW_PRODUCTION_FIRESTORE_SEED,
    confirmProject: process.env.CONFIRM_FIREBASE_PROJECT_ID,
    confirmPublicFeed: process.env.CONFIRM_PUBLIC_FEED_SEED,
    environment: process.env.SEED_ENVIRONMENT,
    emulator: process.env.FIRESTORE_EMULATOR_HOST,
  };
  try {
    delete process.env.ALLOW_FIRESTORE_SEED;
    assert.throws(() => assertSafety(options()), /ALLOW_FIRESTORE_SEED/);

    process.env.ALLOW_FIRESTORE_SEED = "true";
    process.env.SEED_ENVIRONMENT = "development";
    delete process.env.FIRESTORE_EMULATOR_HOST;
    assert.throws(
      () =>
        assertSafety(
          options({ target: "development", projectId: "matchu-5bd75" }),
        ),
      /production-protected/,
    );

    process.env.ALLOW_PRODUCTION_FIRESTORE_SEED = "true";
    process.env.CONFIRM_FIREBASE_PROJECT_ID = "matchu-5bd75";
    process.env.CONFIRM_PUBLIC_FEED_SEED = "true";
    process.env.SEED_ENVIRONMENT = "production";
    assert.doesNotThrow(() =>
      assertSafety(
        options({
          target: "production",
          projectId: "matchu-5bd75",
          createSeedUsers: true,
          includeModerationTestData: false,
          includeReports: false,
          includeRestrictions: false,
        }),
      ),
    );
  } finally {
    if (original.allow === undefined) delete process.env.ALLOW_FIRESTORE_SEED;
    else process.env.ALLOW_FIRESTORE_SEED = original.allow;
    if (original.allowProduction === undefined)
      delete process.env.ALLOW_PRODUCTION_FIRESTORE_SEED;
    else process.env.ALLOW_PRODUCTION_FIRESTORE_SEED = original.allowProduction;
    if (original.confirmProject === undefined)
      delete process.env.CONFIRM_FIREBASE_PROJECT_ID;
    else process.env.CONFIRM_FIREBASE_PROJECT_ID = original.confirmProject;
    if (original.confirmPublicFeed === undefined)
      delete process.env.CONFIRM_PUBLIC_FEED_SEED;
    else process.env.CONFIRM_PUBLIC_FEED_SEED = original.confirmPublicFeed;
    if (original.environment === undefined) delete process.env.SEED_ENVIRONMENT;
    else process.env.SEED_ENVIRONMENT = original.environment;
    if (original.emulator === undefined)
      delete process.env.FIRESTORE_EMULATOR_HOST;
    else process.env.FIRESTORE_EMULATOR_HOST = original.emulator;
  }
});
