const test = require("node:test");
const assert = require("node:assert/strict");

const {
  evaluateAccountAccess,
} = require("../src/shared/accountAccess");

const NOW = new Date("2026-07-26T12:00:00.000Z");

test("legacy accounts are allowed", () => {
  assert.equal(evaluateAccountAccess({}, "posts", NOW).allowed, true);
});

test("only configured features are blocked", () => {
  const user = {
    accountStatus: "restricted",
    restriction: {
      features: ["posts", "chat"],
      reason: "Policy violation",
      expiresAt: new Date("2026-07-27T12:00:00.000Z"),
    },
  };

  assert.equal(
    evaluateAccountAccess(user, "posts", NOW).reason,
    "feature-restricted"
  );
  assert.equal(evaluateAccountAccess(user, "comments", NOW).allowed, true);
});

test("expired restrictions are immediately allowed", () => {
  const user = {
    accountStatus: "restricted",
    restriction: {
      features: ["matching"],
      expiresAt: new Date("2026-07-26T11:59:59.000Z"),
    },
  };

  assert.equal(evaluateAccountAccess(user, "matching", NOW).allowed, true);
});

test("suspended, banned and malformed restricted accounts fail closed", () => {
  assert.equal(
    evaluateAccountAccess({ accountStatus: "suspended" }, "chat", NOW).allowed,
    false
  );
  assert.equal(
    evaluateAccountAccess({ accountStatus: "banned" }, "chat", NOW).allowed,
    false
  );
  assert.equal(
    evaluateAccountAccess({ accountStatus: "restricted" }, "chat", NOW)
      .allowed,
    false
  );
});
