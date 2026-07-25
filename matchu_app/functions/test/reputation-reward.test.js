const test = require("node:test");
const assert = require("node:assert/strict");

const { allocateReputationReward } = require("../reputation/types");

test("awards reputation normally while the score is below 100", () => {
  assert.deepEqual(
    allocateReputationReward({
      requestedReward: 3,
      reputationBefore: 80,
      todayClaimed: 2,
      dailyCap: 10,
    }),
    {
      requested: 3,
      reputationAwarded: 3,
      gemAwarded: 0,
      reputationAfter: 83,
      todayClaimedAfter: 5,
      consumedReward: 3,
      reason: "claimed",
    }
  );
});

test("converts every reward point to gem at 100 without a daily cap", () => {
  const allocation = allocateReputationReward({
    requestedReward: 5,
    reputationBefore: 100,
    todayClaimed: 10,
    dailyCap: 10,
  });

  assert.equal(allocation.reputationAwarded, 0);
  assert.equal(allocation.gemAwarded, 5);
  assert.equal(allocation.reputationAfter, 100);
  assert.equal(allocation.todayClaimedAfter, 10);
  assert.equal(allocation.consumedReward, 5);
  assert.equal(allocation.reason, "claimed_as_gem");
});

test("splits a reward between reputation and gem when reaching 100", () => {
  const allocation = allocateReputationReward({
    requestedReward: 3,
    reputationBefore: 99,
    todayClaimed: 4,
    dailyCap: 10,
  });

  assert.equal(allocation.reputationAwarded, 1);
  assert.equal(allocation.gemAwarded, 2);
  assert.equal(allocation.reputationAfter, 100);
  assert.equal(allocation.todayClaimedAfter, 5);
  assert.equal(allocation.consumedReward, 3);
  assert.equal(allocation.reason, "claimed_with_gem_conversion");
});

test("does not bypass the reputation daily cap before reaching 100", () => {
  const allocation = allocateReputationReward({
    requestedReward: 3,
    reputationBefore: 99,
    todayClaimed: 10,
    dailyCap: 10,
  });

  assert.equal(allocation.reputationAwarded, 0);
  assert.equal(allocation.gemAwarded, 0);
  assert.equal(allocation.reputationAfter, 99);
  assert.equal(allocation.consumedReward, 0);
  assert.equal(allocation.reason, "daily_cap_reached");
});
