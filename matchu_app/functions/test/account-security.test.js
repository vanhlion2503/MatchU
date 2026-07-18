const test = require("node:test");
const assert = require("node:assert/strict");

const { __test } = require("../src/callables/accountSecurity");

test("recent authentication accepts a fresh auth_time", () => {
  const uid = __test.requireRecentAuth({
    auth: {
      uid: "user-1",
      token: { auth_time: Math.floor(Date.now() / 1000) - 30 },
    },
  });
  assert.equal(uid, "user-1");
});

test("recent authentication rejects missing authentication", () => {
  assert.throws(
    () => __test.requireRecentAuth({}),
    (error) => error.code === "unauthenticated"
  );
});

test("recent authentication rejects stale auth_time", () => {
  assert.throws(
    () =>
      __test.requireRecentAuth({
        auth: {
          uid: "user-1",
          token: { auth_time: Math.floor(Date.now() / 1000) - 3600 },
        },
      }),
    (error) => error.code === "failed-precondition"
  );
});
