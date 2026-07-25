const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");
const { FACE_BACKUP_ENCRYPTION_KEY_B64 } = require("../shared/secrets");

const BACKUP_KEY_LENGTH = 32;
const NONCE_LENGTH = 12;
const AAD_PREFIX = "matchu-face-recovery-backup";

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function decodeEncryptionKey() {
  const raw = (FACE_BACKUP_ENCRYPTION_KEY_B64.value() || "").trim();
  if (!raw) {
    throw new HttpsError(
      "failed-precondition",
      "Face recovery backup secret is not configured."
    );
  }

  const key = Buffer.from(raw, "base64");
  if (key.length !== 32) {
    throw new HttpsError(
      "failed-precondition",
      "Face recovery backup secret must decode to 32 bytes."
    );
  }
  return key;
}

function readBackupKey(rawValue) {
  if (typeof rawValue !== "string" || !rawValue.trim()) {
    throw new HttpsError("invalid-argument", "backupKey is required.");
  }

  const backupKey = Buffer.from(rawValue.trim(), "base64");
  if (backupKey.length !== BACKUP_KEY_LENGTH) {
    throw new HttpsError("invalid-argument", "backupKey must be 32 bytes.");
  }
  return backupKey;
}

function aadFor(uid) {
  return Buffer.from(`${AAD_PREFIX}:${uid}:v1`, "utf8");
}

function encryptBackupKey({ uid, backupKey }) {
  const nonce = crypto.randomBytes(NONCE_LENGTH);
  const cipher = crypto.createCipheriv(
    "aes-256-gcm",
    decodeEncryptionKey(),
    nonce
  );
  cipher.setAAD(aadFor(uid));

  const ciphertext = Buffer.concat([cipher.update(backupKey), cipher.final()]);
  const tag = cipher.getAuthTag();

  return {
    algorithm: "AES-256-GCM",
    keyVersion: "v1",
    nonce: nonce.toString("base64"),
    ciphertext: ciphertext.toString("base64"),
    tag: tag.toString("base64"),
  };
}

function decryptBackupKey({ uid, encrypted }) {
  const nonce = Buffer.from(String(encrypted.nonce || ""), "base64");
  const ciphertext = Buffer.from(String(encrypted.ciphertext || ""), "base64");
  const tag = Buffer.from(String(encrypted.tag || ""), "base64");

  if (
    encrypted.algorithm !== "AES-256-GCM" ||
    encrypted.keyVersion !== "v1" ||
    nonce.length !== NONCE_LENGTH ||
    tag.length !== 16 ||
    ciphertext.length === 0
  ) {
    throw new HttpsError("failed-precondition", "Face backup is malformed.");
  }

  try {
    const decipher = crypto.createDecipheriv(
      "aes-256-gcm",
      decodeEncryptionKey(),
      nonce
    );
    decipher.setAAD(aadFor(uid));
    decipher.setAuthTag(tag);
    const backupKey = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]);

    if (backupKey.length !== BACKUP_KEY_LENGTH) {
      throw new Error("Invalid backup key length.");
    }
    return backupKey;
  } catch (error) {
    console.error("Face backup decrypt failed:", error);
    throw new HttpsError("internal", "Unable to decrypt face backup.");
  }
}

async function assertUserFaceVerified(uid) {
  const userSnap = await db.collection("users").doc(uid).get();
  const data = userSnap.data() || {};
  if (data.isFaceVerified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Account must be face verified first."
    );
  }
}

const storeFaceRecoveryBackup = onCall(
  {
    secrets: [FACE_BACKUP_ENCRYPTION_KEY_B64],
  },
  async (request) => {
    const uid = requireAuth(request);
    await assertUserFaceVerified(uid);

    const backupKey = readBackupKey(request.data?.backupKey);
    const requestedGeneration = Number(request.data?.generation || 0);
    if (
      !Number.isSafeInteger(requestedGeneration) ||
      requestedGeneration < 0
    ) {
      throw new HttpsError("invalid-argument", "generation is invalid.");
    }
    const encrypted = encryptBackupKey({ uid, backupKey });
    const faceBackupRef = db
      .collection("users")
      .doc(uid)
      .collection("security")
      .doc("faceBackup");
    const pinBackupRef = db
      .collection("users")
      .doc(uid)
      .collection("security")
      .doc("backup");
    const stateRef = db
      .collection("users")
      .doc(uid)
      .collection("security")
      .doc("passcodeState");

    await db.runTransaction(async (tx) => {
      const [existing, pinBackup, state] = await Promise.all([
        tx.get(faceBackupRef),
        tx.get(pinBackupRef),
        tx.get(stateRef),
      ]);
      const pinGeneration = Number(pinBackup.data()?.generation || 0);
      const stateGeneration = Number(state.data()?.generation || 0);
      if (
        !pinBackup.exists ||
        requestedGeneration !== pinGeneration ||
        (state.exists &&
          (state.data()?.status !== "active" ||
            stateGeneration !== requestedGeneration))
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Recovery-key generation is no longer current."
        );
      }

      const payload = {
        ...encrypted,
        uid,
        version: 1,
        generation: requestedGeneration,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      tx.set(faceBackupRef, payload, { merge: true });
    });

    return { ok: true };
  }
);

const getFaceRecoveryBackupStatus = onCall(async (request) => {
  const uid = requireAuth(request);
  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() || {};
  const faceVerified = userData.isFaceVerified === true;

  if (!faceVerified) {
    return { available: false, faceVerified: false };
  }

  const securityRef = db.collection("users").doc(uid).collection("security");
  const [backupSnap, pinBackupSnap, stateSnap] = await Promise.all([
    securityRef.doc("faceBackup").get(),
    securityRef.doc("backup").get(),
    securityRef.doc("passcodeState").get(),
  ]);
  const faceGeneration = Number(backupSnap.data()?.generation || 0);
  const pinGeneration = Number(pinBackupSnap.data()?.generation || 0);
  const stateGeneration = Number(stateSnap.data()?.generation || 0);
  const generationIsCurrent =
    backupSnap.exists &&
    pinBackupSnap.exists &&
    faceGeneration === pinGeneration &&
    (!stateSnap.exists ||
      (stateSnap.data()?.status === "active" &&
        stateGeneration === faceGeneration));

  return {
    available: generationIsCurrent,
    faceVerified: true,
  };
});

const recoverBackupKeyWithFace = onCall(
  {
    secrets: [FACE_BACKUP_ENCRYPTION_KEY_B64],
  },
  async (request) => {
    const uid = requireAuth(request);
    const sessionId = String(request.data?.sessionId || "").trim();
    if (!sessionId) {
      throw new HttpsError("invalid-argument", "sessionId is required.");
    }

    const recovered = await db.runTransaction(async (tx) => {
      const sessionRef = db.collection("faceReauthSessions").doc(sessionId);
      const sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw new HttpsError("permission-denied", "Face session is invalid.");
      }

      const session = sessionSnap.data() || {};
      const expiresAt = session.expiresAt;
      const expiresMs =
        expiresAt && typeof expiresAt.toMillis === "function"
          ? expiresAt.toMillis()
          : 0;

      if (
        session.uid !== uid ||
        session.status !== "valid" ||
        session.purpose !== "face_reauth" ||
        expiresMs <= Date.now()
      ) {
        throw new HttpsError("permission-denied", "Face session is invalid.");
      }

      const backupRef = db
        .collection("users")
        .doc(uid)
        .collection("security")
        .doc("faceBackup");
      const backupSnap = await tx.get(backupRef);
      if (!backupSnap.exists) {
        throw new HttpsError(
          "not-found",
          "No face recovery backup is available."
        );
      }
      const pinBackupRef = db
        .collection("users")
        .doc(uid)
        .collection("security")
        .doc("backup");
      const pinBackupSnap = await tx.get(pinBackupRef);
      const faceGeneration = Number(backupSnap.data()?.generation || 0);
      const pinGeneration = Number(pinBackupSnap.data()?.generation || 0);
      if (!pinBackupSnap.exists || faceGeneration !== pinGeneration) {
        throw new HttpsError(
          "failed-precondition",
          "Face recovery backup is no longer current."
        );
      }

      const decrypted = decryptBackupKey({
        uid,
        encrypted: backupSnap.data() || {},
      });
      tx.set(
        sessionRef,
        {
          status: "consumed",
          consumedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { backupKey: decrypted, generation: pinGeneration };
    });

    return {
      backupKey: recovered.backupKey.toString("base64"),
      generation: recovered.generation,
    };
  }
);

const deleteFaceRecoveryBackup = onCall(async (request) => {
  const uid = requireAuth(request);

  await db
    .collection("users")
    .doc(uid)
    .collection("security")
    .doc("faceBackup")
    .delete();

  return { ok: true };
});

module.exports = {
  storeFaceRecoveryBackup,
  getFaceRecoveryBackupStatus,
  recoverBackupKeyWithFace,
  deleteFaceRecoveryBackup,
};
