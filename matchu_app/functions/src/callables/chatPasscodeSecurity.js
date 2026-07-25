const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");

const MAX_REAUTH_AGE_SECONDS = 5 * 60;
const REQUIRED_BACKUP_FIELDS = [
  "salt",
  "nonce",
  "ciphertext",
  "mac",
  "kdf",
  "iterations",
  "version",
];

function requireRecentlyAuthenticatedUser(request, nowSeconds = Date.now() / 1000) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const authenticatedAt = Number(request.auth.token?.auth_time || 0);
  if (
    !Number.isFinite(authenticatedAt) ||
    authenticatedAt <= 0 ||
    nowSeconds - authenticatedAt > MAX_REAUTH_AGE_SECONDS
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Recent account authentication is required."
    );
  }
  return request.auth.uid;
}

function readBackupPayload(rawBackup) {
  if (!rawBackup || typeof rawBackup !== "object" || Array.isArray(rawBackup)) {
    throw new HttpsError("invalid-argument", "backup is required.");
  }
  if (!REQUIRED_BACKUP_FIELDS.every((field) => field in rawBackup)) {
    throw new HttpsError("invalid-argument", "backup is incomplete.");
  }
  if (
    rawBackup.kdf !== "PBKDF2-HMAC-SHA256" ||
    rawBackup.iterations !== 150000 ||
    rawBackup.version !== 1
  ) {
    throw new HttpsError("invalid-argument", "backup parameters are invalid.");
  }

  const expectedLengths = {
    salt: 16,
    nonce: 12,
    ciphertext: 32,
    mac: 16,
  };
  for (const [field, expectedLength] of Object.entries(expectedLengths)) {
    if (typeof rawBackup[field] !== "string") {
      throw new HttpsError("invalid-argument", `${field} must be base64.`);
    }
    const value = Buffer.from(rawBackup[field], "base64");
    if (value.length !== expectedLength) {
      throw new HttpsError("invalid-argument", `${field} has invalid length.`);
    }
  }

  return Object.fromEntries(
    REQUIRED_BACKUP_FIELDS.map((field) => [field, rawBackup[field]])
  );
}

const resetChatPasscode = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    const uid = requireRecentlyAuthenticatedUser(request);
    const backup = readBackupPayload(request.data?.backup);
    const userRef = db.collection("users").doc(uid);
    const stateRef = userRef.collection("security").doc("passcodeState");
    const backupRef = userRef.collection("security").doc("backup");
    const faceBackupRef = userRef.collection("security").doc("faceBackup");
    const sessionBackupsRef = userRef.collection("sessionKeyBackups");
    const resetId = crypto.randomUUID();

    const generation = await db.runTransaction(async (transaction) => {
      const stateSnapshot = await transaction.get(stateRef);
      const currentGeneration = Number(
        stateSnapshot.data()?.generation || 0
      );
      const nextGeneration = currentGeneration + 1;
      transaction.set(
        stateRef,
        {
          generation: nextGeneration,
          status: "resetting",
          resetId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return nextGeneration;
    });

    // While status is "resetting", Firestore rules reject stale clients that
    // try to recreate backups encrypted by an older recovery key.
    await db.recursiveDelete(sessionBackupsRef);

    await db.runTransaction(async (transaction) => {
      const latestState = await transaction.get(stateRef);
      if (
        latestState.data()?.generation !== generation ||
        latestState.data()?.resetId !== resetId
      ) {
        throw new HttpsError(
          "aborted",
          "A newer PIN reset has replaced this request."
        );
      }
      transaction.delete(faceBackupRef);
      transaction.set(backupRef, {
        ...backup,
        generation,
        credentialVersion: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        resetAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(
        stateRef,
        {
          generation,
          status: "active",
          resetId: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    return { ok: true, generation };
  }
);

module.exports = {
  resetChatPasscode,
  __test: {
    readBackupPayload,
    requireRecentlyAuthenticatedUser,
  },
};
