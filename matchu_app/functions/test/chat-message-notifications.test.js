const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __test,
} = require("../src/triggers/chatMessageNotifications");

test("only the active queue claim may finalize a dispatch", () => {
  assert.equal(
    __test.shouldFinalizeClaim(
      { status: "sending", version: 4, claimedVersion: 4 },
      4
    ),
    true
  );
});

test("an older dispatch cannot overwrite a newer pending message", () => {
  assert.equal(
    __test.shouldFinalizeClaim(
      { status: "pending", version: 5, claimedVersion: 4 },
      4
    ),
    false
  );
});

test("notification text is bounded", () => {
  const result = __test.truncateNotificationText("a".repeat(200));
  assert.equal(result.length, 163);
  assert.equal(result.endsWith("..."), true);
});

test("chat mute without an expiry stays active until manually disabled", () => {
  assert.equal(__test.isChatMuteActive({ mutedUntil: null }, Date.now()), true);
});

test("timed chat mute is active only before its expiry", () => {
  const now = 10_000;
  assert.equal(
    __test.isChatMuteActive({ mutedUntil: { toMillis: () => now + 1 } }, now),
    true
  );
  assert.equal(
    __test.isChatMuteActive({ mutedUntil: { toMillis: () => now } }, now),
    false
  );
});
