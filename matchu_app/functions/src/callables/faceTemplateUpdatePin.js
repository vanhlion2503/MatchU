const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");

const UPDATE_AUTHORIZATION_TTL_MS = 5 * 60 * 1000;
const BACKUP_KEY_LENGTH = 32;
const MIN_KDF_ITERATIONS = 10_000;
const MAX_KDF_ITERATIONS = 1_000_000;

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function requireDeviceId(value) {
  const deviceId = String(value || "").trim();
  if (!deviceId || deviceId.length > 128) {
    throw new HttpsError("invalid-argument", "A valid deviceId is required.");
  }
  return deviceId;
}

function decodeBase64Field(value, fieldName) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`Missing ${fieldName}.`);
  }
  return Buffer.from(value.trim(), "base64");
}

function verifyPasscodeAgainstBackup(passcode, backup) {
  if (!/^\d{6}$/.test(passcode)) return false;
  if (
    backup?.kdf !== "PBKDF2-HMAC-SHA256" ||
    Number(backup?.version) !== 1
  ) {
    return false;
  }

  try {
    const salt = decodeBase64Field(backup.salt, "salt");
    const nonce = decodeBase64Field(backup.nonce, "nonce");
    const ciphertext = decodeBase64Field(backup.ciphertext, "ciphertext");
    const tag = decodeBase64Field(backup.mac, "mac");
    const iterations = Number(backup.iterations);
    if (
      salt.length < 16 ||
      nonce.length !== 12 ||
      tag.length !== 16 ||
      ciphertext.length === 0 ||
      !Number.isInteger(iterations) ||
      iterations < MIN_KDF_ITERATIONS ||
      iterations > MAX_KDF_ITERATIONS
    ) {
      return false;
    }

    const key = crypto.pbkdf2Sync(
      Buffer.from(passcode, "utf8"),
      salt,
      iterations,
      32,
      "sha256"
    );
    const decipher = crypto.createDecipheriv("aes-256-gcm", key, nonce);
    decipher.setAuthTag(tag);
    const backupKey = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]);
    return backupKey.length === BACKUP_KEY_LENGTH;
  } catch (_) {
    return false;
  }
}

const authorizeFaceTemplateUpdateWithPin = onCall(async (request) => {
  const uid = requireAuth(request);
  const deviceId = requireDeviceId(request.data?.deviceId);
  const passcode = String(request.data?.passcode || "").trim();
  if (!/^\d{6}$/.test(passcode)) {
    throw new HttpsError(
      "invalid-argument",
      "The chat PIN must contain exactly six digits."
    );
  }

  const [enrollmentSnap, backupSnap] = await Promise.all([
    db.collection("faceEnrollments").doc(uid).get(),
    db
      .collection("users")
      .doc(uid)
      .collection("security")
      .doc("backup")
      .get(),
  ]);
  if (!enrollmentSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "A face enrollment is required before it can be updated."
    );
  }
  if (!backupSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "A chat PIN must be configured before updating face data."
    );
  }
  if (!verifyPasscodeAgainstBackup(passcode, backupSnap.data() || {})) {
    throw new HttpsError("permission-denied", "The chat PIN is incorrect.");
  }

  const authorizationId = crypto.randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + UPDATE_AUTHORIZATION_TTL_MS);
  await db
    .collection("faceTemplateUpdateAuthorizations")
    .doc(authorizationId)
    .create({
      uid,
      deviceId,
      purpose: "face_template_update",
      status: "valid",
      method: "chat_pin",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

  return {
    authorizationId,
    expiresAt: expiresAt.toISOString(),
  };
});

module.exports = {
  authorizeFaceTemplateUpdateWithPin,
  __test: {
    requireDeviceId,
    verifyPasscodeAgainstBackup,
  },
};
