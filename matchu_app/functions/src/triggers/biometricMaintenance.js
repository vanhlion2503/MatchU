const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");

const BATCH_LIMIT = 400;
const EXPIRING_COLLECTIONS = [
  "faceReauthSessions",
  "faceLivenessChallenges",
  "faceLivenessEvidenceFingerprints",
  "faceTemplateUpdateAuthorizations",
];

async function deleteExpiredPage(collectionName, now) {
  const snapshot = await db
    .collection(collectionName)
    .where("expiresAt", "<=", now)
    .limit(BATCH_LIMIT)
    .get();
  if (snapshot.empty) return 0;

  const batch = db.batch();
  for (const document of snapshot.docs) {
    batch.delete(document.ref);
  }
  await batch.commit();
  return snapshot.size;
}

async function cleanupExpiredBiometricDocuments() {
  const now = admin.firestore.Timestamp.now();
  for (const collectionName of EXPIRING_COLLECTIONS) {
    let deleted;
    do {
      deleted = await deleteExpiredPage(collectionName, now);
    } while (deleted === BATCH_LIMIT);
  }
}

const maintainBiometricDocuments = onSchedule(
  {
    schedule: "every 24 hours",
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  cleanupExpiredBiometricDocuments
);

module.exports = {
  maintainBiometricDocuments,
  __test: {
    EXPIRING_COLLECTIONS,
  },
};
