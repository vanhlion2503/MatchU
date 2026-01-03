const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();
const db = admin.firestore();

exports.migrateTempChatMessages = onDocumentCreated(
  "chatRooms/{roomId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const roomData = snap.data();

    // ❌ Không phải room migrate
    if (!roomData.fromTempRoom) return;

    // 🔒 Chống chạy lại
    if (roomData.migrated === true) return;

    const tempRoomId = roomData.fromTempRoom;

    const tempMessagesSnap = await db
      .collection("tempChats")
      .doc(tempRoomId)
      .collection("messages")
      .orderBy("createdAt")
      .get();

    // Không có tin nhắn
    if (tempMessagesSnap.empty) {
      await snap.ref.update({ migrated: true });
      return;
    }

    let batch = db.batch();
    let count = 0;

    for (const doc of tempMessagesSnap.docs) {
      const data = doc.data();

      if (data.type === "system" || data.code) {
        continue;
      }

      const newMsgRef = snap.ref.collection("messages").doc();

      batch.set(newMsgRef, {
        ...data,
        createdAt: data.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
      });

      count++;

      // Commit tránh quá 500 ops
      if (count >= 450) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }

    // ✅ Đánh dấu migrate xong
    await snap.ref.update({
      migrated: true,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

exports.consumePreKey = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  const { targetUid, preKeyId } = request.data;

  if (!callerUid) {
    throw new Error("Unauthenticated");
  }

  if (!targetUid || !preKeyId) {
    throw new Error("Missing parameters");
  }

  const ref = db
    .collection("users")
    .doc(targetUid)
    .collection("encryptionKeys")
    .doc("signal");

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);

    if (!snap.exists) {
      throw new Error("Signal keys not found");
    }

    const data = snap.data();
    const preKeys = data.preKeys || [];

    const exists = preKeys.find((p) => p.id === preKeyId);

    // ✅ idempotent — đã consume thì thôi
    if (!exists) return;

    const updated = preKeys.filter((p) => p.id !== preKeyId);

    tx.update(ref, { preKeys: updated });
  });

  return { ok: true };
});

