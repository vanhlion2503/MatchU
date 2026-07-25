const assert = require("node:assert/strict");
const test = require("node:test");

const {
  __test: { readBackupPayload, requireRecentlyAuthenticatedUser },
} = require("../src/callables/chatPasscodeSecurity");

function validBackup() {
  return {
    salt: Buffer.alloc(16).toString("base64"),
    nonce: Buffer.alloc(12).toString("base64"),
    ciphertext: Buffer.alloc(32).toString("base64"),
    mac: Buffer.alloc(16).toString("base64"),
    kdf: "PBKDF2-HMAC-SHA256",
    iterations: 150000,
    version: 1,
  };
}

test("accepts a complete encrypted backup wrapper", () => {
  assert.deepEqual(readBackupPayload(validBackup()), validBackup());
});

test("rejects malformed encrypted backup wrappers", () => {
  assert.throws(() =>
    readBackupPayload({ ...validBackup(), ciphertext: "invalid" })
  );
});

test("requires a recently authenticated Firebase session", () => {
  const now = 10_000;
  assert.equal(
    requireRecentlyAuthenticatedUser(
      { auth: { uid: "user-1", token: { auth_time: now - 60 } } },
      now
    ),
    "user-1"
  );
  assert.throws(() =>
    requireRecentlyAuthenticatedUser(
      { auth: { uid: "user-1", token: { auth_time: now - 301 } } },
      now
    )
  );
});
