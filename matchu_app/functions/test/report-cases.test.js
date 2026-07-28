const test = require("node:test");
const assert = require("node:assert/strict");
const {
  _test: {
    buildReportCaseId,
    calculatePriority,
    higherPriority,
    moderationPriority,
    needsContentModeration,
    normalizeModerationStatus,
    normalizeReport,
  },
} = require("../src/triggers/reportCases");

test("builds stable report case ids without exposing target identifiers", () => {
  const first = buildReportCaseId("post", "post/unsafe");
  const second = buildReportCaseId("post", "post/unsafe");
  assert.equal(first, second);
  assert.match(first, /^post_[a-f0-9]{40}$/);
  assert.equal(first.includes("/"), false);
});

test("normalizes all report sources without changing original payloads", () => {
  const post = normalizeReport("postReports", "report-1", {
    fromUid: " reporter ",
    toUid: "author",
    postId: "post-1",
    categoryKey: "spam",
    reasonKey: "repeated_posts",
    imageUrls: ["https://example.com/evidence.jpg"],
  });
  const matching = normalizeReport("userMatchingReports", "report-2", {
    fromUid: "reporter",
    toUid: "target",
    roomId: "room-1",
    reason: "quayroi",
  });

  assert.equal(post.type, "post");
  assert.equal(post.targetId, "post-1");
  assert.equal(post.reporterUid, "reporter");
  assert.equal(matching.type, "matching");
  assert.equal(matching.contextId, "room-1");
  assert.equal(matching.reasonKey, "quayroi");
});

test("raises report case priority for volume and high-risk reasons", () => {
  assert.equal(calculatePriority({ reportCount: 1, categoryKey: "spam" }), "medium");
  assert.equal(calculatePriority({ reportCount: 1, categoryKey: "scam" }), "high");
  assert.equal(calculatePriority({ reportCount: 10, categoryKey: "spam" }), "critical");
  assert.equal(higherPriority("high", "medium"), "high");
});

test("normalizes legacy moderation states into the unified report queue", () => {
  assert.equal(normalizeModerationStatus("processing"), "pending_moderation");
  assert.equal(normalizeModerationStatus("human_review"), "review_required");
  assert.equal(needsContentModeration({ moderationStatus: "review_required" }), true);
  assert.equal(needsContentModeration({ moderationStatus: "approved" }), false);
  assert.equal(moderationPriority({
    moderationStatus: "review_required",
    videoModeration: { overallSeverity: 4 },
  }), "critical");
});
