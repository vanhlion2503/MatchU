const crypto = require("crypto");
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  __test: { requireDeviceId, verifyPasscodeAgainstBackup },
} = require("../src/callables/faceTemplateUpdatePin");

function backupFixture(passcode) {
  const salt = crypto.randomBytes(16);
  const nonce = crypto.randomBytes(12);
  const backupKey = crypto.randomBytes(32);
  const iterations = 150000;
  const key = crypto.pbkdf2Sync(
    Buffer.from(passcode, "utf8"),
    salt,
    iterations,
    32,
    "sha256"
  );
  const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
  const ciphertext = Buffer.concat([
    cipher.update(backupKey),
    cipher.final(),
  ]);
  return {
    salt: salt.toString("base64"),
    nonce: nonce.toString("base64"),
    ciphertext: ciphertext.toString("base64"),
    mac: cipher.getAuthTag().toString("base64"),
    kdf: "PBKDF2-HMAC-SHA256",
    iterations,
    version: 1,
  };
}

test("verifies the configured six-digit chat PIN", () => {
  const backup = backupFixture("123456");
  assert.equal(verifyPasscodeAgainstBackup("123456", backup), true);
  assert.equal(verifyPasscodeAgainstBackup("654321", backup), false);
  assert.equal(verifyPasscodeAgainstBackup("12345", backup), false);
});

test("requires a bounded device identifier", () => {
  assert.equal(requireDeviceId(" device-a "), "device-a");
  assert.throws(() => requireDeviceId(""));
  assert.throws(() => requireDeviceId("a".repeat(129)));
});
