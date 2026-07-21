const test = require("node:test");
const assert = require("node:assert/strict");

const { __test } = require("../src/callables/chatMessages");

test("wrapped room key targets receive stable key-version document ids", () => {
  const result = __test.normalizeWrappedKeyTargets(
    [
      { userId: "user-a", deviceId: "phone", encryptedKey: "abc=" },
      { userId: "user-b", deviceId: "tablet", encryptedKey: "def=" },
    ],
    ["user-a", "user-b"],
    3
  );

  assert.deepEqual(
    result.map((entry) => entry.targetId),
    ["user-a_phone_3", "user-b_tablet_3"]
  );
});

test("wrapped room key targets reject duplicates", () => {
  assert.throws(
    () =>
      __test.normalizeWrappedKeyTargets(
        [
          { userId: "user-a", deviceId: "phone", encryptedKey: "abc=" },
          { userId: "user-a", deviceId: "phone", encryptedKey: "def=" },
        ],
        ["user-a", "user-b"],
        0
      ),
    (error) => error.code === "invalid-argument"
  );
});

test("wrapped room key targets reject a non-participant", () => {
  assert.throws(
    () =>
      __test.normalizeWrappedKeyTargets(
        [{ userId: "intruder", deviceId: "phone", encryptedKey: "abc=" }],
        ["user-a", "user-b"],
        0
      ),
    (error) => error.code === "invalid-argument"
  );
});
