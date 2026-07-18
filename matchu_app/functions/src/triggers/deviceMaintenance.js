const { onSchedule } = require("firebase-functions/v2/scheduler");

const { admin, db } = require("../shared/firebase");

const DAY_MS = 24 * 60 * 60 * 1000;
const STALE_AFTER_DAYS = 60;
const DELETE_AFTER_DAYS = 180;
const BATCH_LIMIT = 100;
const MIGRATION_PAGE_LIMIT = 200;
const MIGRATION_MAX_PAGES = 25;

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
    batch.delete(notificationDeviceRef(doc.ref));
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
      },
      { merge: true }
    );
    batch.set(
      notificationDeviceRef(doc.ref),
      {
        status: "stale",
        pushEnabled: false,
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
        notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
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

const migrateLegacyNotificationDevices = onSchedule(
  {
    schedule: "every day 02:30",
    timeZone: "Asia/Bangkok",
  },
  async () => {
    let cursor = null;
    let scannedCount = 0;
    let migratedCount = 0;

    for (let page = 0; page < MIGRATION_MAX_PAGES; page += 1) {
      let query = db
        .collectionGroup("devices")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(MIGRATION_PAGE_LIMIT);
      if (cursor) query = query.startAfter(cursor);

      const snap = await query.get();
      if (snap.empty) break;
      scannedCount += snap.size;

      const batch = db.batch();
      let writes = 0;
      for (const doc of snap.docs) {
        const data = doc.data() || {};
        if (!hasLegacyPushFields(data)) continue;

        const pushEnabled = data.pushEnabled === true;
        const token = cleanString(data.fcmToken);
        batch.set(
          notificationDeviceRef(doc.ref),
          {
            platform: cleanString(data.platform) || "unknown",
            status: normalizeDeviceStatus(data.e2eeStatus),
            lastActiveAt:
              data.lastActiveAt || admin.firestore.FieldValue.serverTimestamp(),
            pushEnabled,
            notificationPermission:
              cleanString(data.notificationPermission) ||
              (pushEnabled ? "authorized" : "denied"),
            notificationUpdatedAt:
              data.notificationUpdatedAt ||
              admin.firestore.FieldValue.serverTimestamp(),
            ...(token ? { fcmToken: token } : {}),
            ...(data.fcmTokenUpdatedAt
              ? { fcmTokenUpdatedAt: data.fcmTokenUpdatedAt }
              : {}),
          },
          { merge: true }
        );
        batch.update(doc.ref, {
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
          pushEnabled: admin.firestore.FieldValue.delete(),
          notificationPermission: admin.firestore.FieldValue.delete(),
          notificationUpdatedAt: admin.firestore.FieldValue.delete(),
          lastNotificationOpenedAt: admin.firestore.FieldValue.delete(),
        });
        writes += 2;
        migratedCount += 1;
      }

      if (writes > 0) await batch.commit();
      cursor = snap.docs[snap.docs.length - 1];
      if (snap.size < MIGRATION_PAGE_LIMIT) break;
    }

    console.log("Legacy notification device migration completed", {
      scannedCount,
      migratedCount,
    });
  }
);

function notificationDeviceRef(publicDeviceRef) {
  const userRef = publicDeviceRef.parent.parent;
  return userRef.collection("notificationDevices").doc(publicDeviceRef.id);
}

function hasLegacyPushFields(data) {
  return [
    "fcmToken",
    "fcmTokenUpdatedAt",
    "pushEnabled",
    "notificationPermission",
    "notificationUpdatedAt",
    "lastNotificationOpenedAt",
  ].some((field) => Object.prototype.hasOwnProperty.call(data, field));
}

function normalizeDeviceStatus(value) {
  const status = cleanString(value);
  return TERMINAL_STATUSES.has(status) || status === "active"
    ? status
    : "active";
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

module.exports = {
  cleanupStaleUserDevices,
  migrateLegacyNotificationDevices,
};
