const test = require("node:test");
const assert = require("node:assert/strict");

const { __test } = require("../src/triggers/videoModeration");

test("keeps a manual admin decision for the video generation it reviewed", () => {
  assert.equal(__test.hasAdminDecisionForObject({
    moderationSource: "admin_manual",
    adminModeration: { videoStorageGeneration: "generation-1" },
  }, { generation: "generation-1" }), true);
});

test("allows automatic moderation for a newly uploaded video generation", () => {
  assert.equal(__test.hasAdminDecisionForObject({
    moderationSource: "admin_manual",
    adminModeration: { videoStorageGeneration: "generation-1" },
  }, { generation: "generation-2" }), false);
});

test("does not lock automatic moderation without an explicit admin generation", () => {
  assert.equal(__test.hasAdminDecisionForObject({
    moderationSource: "gemini_video",
    adminModeration: {},
  }, { generation: "generation-1" }), false);
});

test("keeps an admin decision made after upload but before the trigger claim", () => {
  assert.equal(__test.hasAdminDecisionForObject({
    moderationSource: "admin_manual",
    adminModeration: { updatedAt: new Date("2026-07-27T01:01:00Z") },
  }, {
    generation: "generation-1",
    timeCreated: "2026-07-27T01:00:00Z",
  }), true);
});
