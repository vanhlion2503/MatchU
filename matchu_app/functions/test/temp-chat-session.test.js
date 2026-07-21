const test = require("node:test");
const assert = require("node:assert/strict");

const { __test } = require("../src/callables/tempChatSession");

test("normalizes supported gender aliases", () => {
  assert.equal(__test.normalizeGender("nam"), "male");
  assert.equal(__test.normalizeGender("Nữ"), "female");
  assert.equal(__test.normalizeGender("unknown"), "random");
});

test("matching preference must be mutual", () => {
  assert.equal(
    __test.isMutualMatch(
      { gender: "male", targetGender: "female" },
      { gender: "female", targetGender: "male" }
    ),
    true
  );
  assert.equal(
    __test.isMutualMatch(
      { gender: "male", targetGender: "female" },
      { gender: "female", targetGender: "female" }
    ),
    false
  );
});

test("verified users do not consume daily quota", () => {
  const patch = __test.quotaPatch(
    { isFaceVerified: true, dailyMatchingCount: 10 },
    new Date("2026-07-16T12:00:00.000Z")
  );
  assert.deepEqual(patch, {});
});

test("daily quota resets using the Bangkok calendar day", () => {
  const now = new Date("2026-07-16T18:30:00.000Z");
  assert.equal(__test.bangkokDateKey(now), "2026-07-17");
  assert.deepEqual(
    __test.quotaPatch(
      { dailyMatchingDate: "2026-07-16", dailyMatchingCount: 9 },
      now
    ),
    { dailyMatchingDate: "2026-07-17", dailyMatchingCount: 1 }
  );
});

test("daily quota rejects the eleventh unverified match", () => {
  const now = new Date("2026-07-16T12:00:00.000Z");
  assert.throws(
    () => __test.quotaPatch({
      dailyMatchingDate: __test.bangkokDateKey(now),
      dailyMatchingCount: 10,
    }, now),
    (error) => error.code === "resource-exhausted"
  );
});

test("only resumes an active temp room that contains the user", () => {
  assert.equal(
    __test.isActiveTempRoomForUser(
      { status: "active", participants: ["user-a", "user-b"] },
      "user-a"
    ),
    true
  );
  assert.equal(
    __test.isActiveTempRoomForUser(
      { status: "ended", participants: ["user-a", "user-b"] },
      "user-a"
    ),
    false
  );
  assert.equal(
    __test.isActiveTempRoomForUser(
      { status: "active", participants: ["user-b", "user-c"] },
      "user-a"
    ),
    false
  );
});
