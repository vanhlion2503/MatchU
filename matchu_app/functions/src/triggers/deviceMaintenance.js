const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");

const DAY_MS = 24 * 60 * 60 * 1000;
const STALE_AFTER_DAYS = 60;
const DELETE_AFTER_DAYS = 180;
const BATCH_LIMIT = 100;

const TERMINAL_STATUSES = new Set(["inactive", "revoked", "stale"]);

const cleanupStaleUserDevices = onSchedule(
  {
    schedule: "every monday 03:00",
    timeZone: "Asia/Bangkok",
  },
  async () => {
    const nowMs = Date.now();
    const staleCutoff = admin.firestore.Timestamp.fromMillis(
      nowMs - STALE_AFTER_DAYS * DAY_MS
    );
    const deleteCutoff = admin.firestore.Timestamp.fromMillis(
      nowMs - DELETE_AFTER_DAYS * DAY_MS
    );

    const deletedCount = await deleteExpiredDevices(deleteCutoff);
    const staleCount = await markStaleDevices(staleCutoff);

    console.log("Device maintenance completed", {
      deletedCount,
      staleCount,
    });
  }
);

async function deleteExpiredDevices(deleteCutoff) {
  const snap = await db
    .collectionGroup("devices")
    .where("lastActiveAt", "<", deleteCutoff)
    .limit(BATCH_LIMIT)
    .get();

  if (snap.empty) return 0;

  const batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const status = cleanString(data.e2eeStatus);

    if (!TERMINAL_STATUSES.has(status)) {
      continue;
    }

    batch.delete(doc.ref);
    count += 1;
  }

  if (count > 0) {
    await batch.commit();
  }

  return count;
}

async function markStaleDevices(staleCutoff) {
  const snap = await db
    .collectionGroup("devices")
    .where("lastActiveAt", "<", staleCutoff)
    .limit(BATCH_LIMIT)
    .get();

  if (snap.empty) return 0;

  const batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const status = cleanString(data.e2eeStatus);

    if (status === "inactive" || status === "revoked" || status === "stale") {
      continue;
    }

    batch.set(
      doc.ref,
      {
        e2eeStatus: "stale",
        e2eeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
        pushEnabled: false,
      },
      { merge: true }
    );
    count += 1;
  }

  if (count > 0) {
    await batch.commit();
  }

  return count;
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

module.exports = {
  cleanupStaleUserDevices,
};
