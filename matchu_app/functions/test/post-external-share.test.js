const test = require("node:test");
const assert = require("node:assert/strict");

const { _test } = require("../src/callables/recordPostExternalShare");

test("validates share event identifiers", () => {
  assert.equal(_test.normalizeIdentifier("post_123"), "post_123");
  assert.equal(_test.normalizeIdentifier("not/safe"), "");
  assert.equal(
    _test.normalizeEventId("550e8400-e29b-41d4-a716-446655440000"),
    "550e8400-e29b-41d4-a716-446655440000"
  );
  assert.equal(_test.normalizeEventId("event_1"), "");
});

test("accepts native, copy, and in-app chat share methods", () => {
  assert.equal(_test.isAllowedMethod("native"), true);
  assert.equal(_test.isAllowedMethod("copy"), true);
  assert.equal(_test.isAllowedMethod("chat"), true);
  assert.equal(_test.isAllowedMethod("unknown"), false);
});

test("allows only public approved active posts", () => {
  const base = {
    visibility: "public",
    moderationStatus: "approved",
    deletedAt: null,
  };
  assert.equal(_test.isExternallyShareable(base), true);
  assert.equal(
    _test.isExternallyShareable({ ...base, visibility: "private" }),
    false
  );
  assert.equal(
    _test.isExternallyShareable({ ...base, deletedAt: new Date() }),
    false
  );
  assert.equal(
    _test.isExternallyShareable({
      ...base,
      moderationStatus: "pending_moderation",
    }),
    false
  );
});

test("normalizes legacy and malformed counters", () => {
  assert.equal(
    _test.externalShareCountOf({ stats: { externalShareCount: 4 } }),
    4
  );
  assert.equal(
    _test.externalShareCountOf({ stats: { externalShareCount: -2 } }),
    0
  );
  assert.equal(_test.externalShareCountOf({ stats: {} }), 0);
});
