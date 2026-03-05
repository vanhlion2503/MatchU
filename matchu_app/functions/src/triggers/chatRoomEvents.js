const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const { admin, db } = require("../shared/firebase");

const migrateTempChatMessages = onDocumentCreated(
  "chatRooms/{roomId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const roomData = snap.data();

    if (!roomData.fromTempRoom) return;
    if (roomData.migrated === true) return;

    const tempRoomId = roomData.fromTempRoom;

    const tempMessagesSnap = await db
      .collection("tempChats")
      .doc(tempRoomId)
      .collection("messages")
      .orderBy("createdAt")
      .get();

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

      if (count >= 450) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }

    await snap.ref.update({
      migrated: true,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
);

const cleanupViewedImageMessage = onDocumentUpdated(
  "chatRooms/{roomId}/messages/{messageId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || !after) return;
    if (before.type !== "image") return;
    if (before.viewOnce !== true) return;
    if (after.type === "deleted" || after.imageDeleted === true) return;

    const beforeViewed = before.viewedBy || {};
    const afterViewed = after.viewedBy || {};

    const newViewers = Object.keys(afterViewed).filter(
      (uid) => !beforeViewed[uid]
    );
    if (newViewers.length === 0) return;

    const viewerUid = newViewers.find(
      (uid) => uid && uid !== before.senderId
    );
    if (!viewerUid) return;

    const imagePath = after.imagePath;

    if (imagePath && typeof imagePath === "string") {
      try {
        await admin.storage().bucket().file(imagePath).delete();
      } catch (_) {
        // Ignore missing files or transient failures.
      }
    }

    await event.data.after.ref.update({
      type: "deleted",
      text: "Ảnh đã bị xóa",
      imagePath: admin.firestore.FieldValue.delete(),
      imageDeleted: true,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedBy: viewerUid,
    });

    try {
      const roomRef = db.collection("chatRooms").doc(event.params.roomId);
      const roomSnap = await roomRef.get();
      if (!roomSnap.exists) return;

      const roomData = roomSnap.data();
      const lastAt = roomData.lastMessageAt;
      const createdAt = after.createdAt;

      if (
        lastAt &&
        createdAt &&
        lastAt.toMillis &&
        createdAt.toMillis &&
        lastAt.toMillis() === createdAt.toMillis()
      ) {
        await roomRef.update({
          lastMessage: "Ảnh đã bị xóa",
          lastMessageType: "deleted",
          lastMessageCipher: admin.firestore.FieldValue.delete(),
          lastMessageIv: admin.firestore.FieldValue.delete(),
          lastMessageKeyId: 0,
          lastSenderId: after.senderId || viewerUid,
        });
      }
    } catch (_) {}
  }
);

module.exports = {
  migrateTempChatMessages,
  cleanupViewedImageMessage,
};
