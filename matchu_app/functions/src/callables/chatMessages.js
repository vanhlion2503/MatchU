const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { admin, db } = require("../shared/firebase");

const MAX_B64_FIELD_LENGTH = 8192;
const MAX_REPLY_TEXT_LENGTH = 500;
const MAX_WRAPPED_KEYS_PER_CALL = 20;
const ALLOWED_MESSAGE_TYPES = new Set(["text", "post_share"]);
const BLOCKED_DEVICE_STATUSES = new Set(["inactive", "revoked", "stale"]);

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanNullableString(value, maxLength) {
  const cleaned = cleanString(value);
  if (!cleaned) return null;
  return cleaned.length > maxLength ? cleaned.slice(0, maxLength) : cleaned;
}

function toInt(value) {
  if (Number.isInteger(value)) return value;
  if (typeof value === "number") return Math.trunc(value);
  if (typeof value === "string" && value.trim()) {
    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function assertBase64Field(name, value) {
  const cleaned = cleanString(value);
  if (!cleaned) {
    throw new HttpsError("invalid-argument", `${name} is required.`);
  }
  if (cleaned.length > MAX_B64_FIELD_LENGTH) {
    throw new HttpsError("invalid-argument", `${name} is too large.`);
  }
  return cleaned;
}

function participantsFromRoom(roomData) {
  return Array.isArray(roomData.participants)
    ? roomData.participants.filter((value) => typeof value === "string")
    : [];
}

function otherParticipant(participants, uid) {
  return participants.find((participant) => participant !== uid) || "";
}

function sessionKeyDocId(userId, deviceId, keyId) {
  const base = `${userId}_${deviceId}`;
  return keyId === 0 ? base : `${base}_${keyId}`;
}

async function hasBlockRelationship(userA, userB) {
  if (!userA || !userB || userA === userB) return false;

  const [outgoingBlock, incomingBlock] = await Promise.all([
    db.collection("users").doc(userA).collection("blockedUsers").doc(userB).get(),
    db.collection("users").doc(userB).collection("blockedUsers").doc(userA).get(),
  ]);

  return outgoingBlock.exists || incomingBlock.exists;
}

const sendEncryptedChatMessage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const uid = request.auth.uid;
  const roomId = cleanString(request.data?.roomId);
  const ciphertext = assertBase64Field("ciphertext", request.data?.ciphertext);
  const iv = assertBase64Field("iv", request.data?.iv);
  const keyId = toInt(request.data?.keyId);
  const type = cleanString(request.data?.type) || "text";

  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId is required.");
  }
  if (keyId == null || keyId < 0) {
    throw new HttpsError("invalid-argument", "keyId is invalid.");
  }
  if (!ALLOWED_MESSAGE_TYPES.has(type)) {
    throw new HttpsError("invalid-argument", "Message type is not supported.");
  }

  const roomRef = db.collection("chatRooms").doc(roomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) {
    throw new HttpsError("not-found", "Chat room not found.");
  }

  const roomData = roomSnap.data() || {};
  const participants = participantsFromRoom(roomData);
  if (!participants.includes(uid)) {
    throw new HttpsError("permission-denied", "User is not a room participant.");
  }

  const recipientUid = otherParticipant(participants, uid);
  if (!recipientUid) {
    throw new HttpsError("failed-precondition", "Chat room participants are invalid.");
  }
  if (await hasBlockRelationship(uid, recipientUid)) {
    throw new HttpsError(
      "failed-precondition",
      "Cannot send messages because one participant has blocked the other."
    );
  }

  const currentKeyId = toInt(roomData.currentKeyId) || 0;
  if (keyId !== currentKeyId) {
    throw new HttpsError("failed-precondition", "Message key is no longer current.", {
      currentKeyId,
    });
  }

  const messageRef = roomRef.collection("messages").doc();
  const replyToId = cleanNullableString(request.data?.replyToId, 160);
  const replyText = cleanNullableString(request.data?.replyText, MAX_REPLY_TEXT_LENGTH);
  const clientMessageId = cleanNullableString(request.data?.clientMessageId, 120);

  const batch = db.batch();
  batch.set(messageRef, {
    senderId: uid,
    ciphertext,
    iv,
    keyId,
    type,
    ...(type === "post_share"
      ? { notificationPreview: "Đã chia sẻ một bài viết" }
      : {}),
    replyToId,
    replyText,
    ...(clientMessageId ? { clientMessageId } : {}),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.update(roomRef, {
    lastMessage: "\uD83D\uDD10 Tin nh\u1EAFn \u0111\u01B0\u1EE3c m\u00E3 h\u00F3a",
    lastMessageType: type === "post_share" ? type : "encrypted",
    lastMessageCipher: ciphertext,
    lastMessageIv: iv,
    lastMessageKeyId: keyId,
    lastSenderId: uid,
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    [`deletedFor.${recipientUid}`]: admin.firestore.FieldValue.delete(),
    [`unread.${recipientUid}`]: admin.firestore.FieldValue.increment(1),
    [`unread.${uid}`]: 0,
  });

  await batch.commit();

  return {
    messageId: messageRef.id,
    roomId,
    keyId,
  };
});

const publishWrappedRoomKeys = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const uid = request.auth.uid;
  const roomId = cleanString(request.data?.roomId);
  const keyId = toInt(request.data?.keyId);
  const keys = Array.isArray(request.data?.keys) ? request.data.keys : [];

  if (!roomId) {
    throw new HttpsError("invalid-argument", "roomId is required.");
  }
  if (keyId == null || keyId < 0) {
    throw new HttpsError("invalid-argument", "keyId is invalid.");
  }
  if (keys.length === 0 || keys.length > MAX_WRAPPED_KEYS_PER_CALL) {
    throw new HttpsError("invalid-argument", "Invalid wrapped key batch size.");
  }

  const roomRef = db.collection("chatRooms").doc(roomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) {
    throw new HttpsError("not-found", "Chat room not found.");
  }

  const participants = participantsFromRoom(roomSnap.data() || {});
  if (!participants.includes(uid)) {
    throw new HttpsError("permission-denied", "User is not a room participant.");
  }

  const batch = db.batch();
  let writeCount = 0;

  for (const rawKey of keys) {
    const userId = cleanString(rawKey?.userId);
    const deviceId = cleanString(rawKey?.deviceId);
    const encryptedKey = assertBase64Field("encryptedKey", rawKey?.encryptedKey);

    if (!userId || !deviceId || !participants.includes(userId)) {
      throw new HttpsError("invalid-argument", "Wrapped key target is invalid.");
    }

    const deviceSnap = await db
      .collection("users")
      .doc(userId)
      .collection("devices")
      .doc(deviceId)
      .get();
    if (!deviceSnap.exists) {
      throw new HttpsError("failed-precondition", "Target device does not exist.");
    }

    const deviceData = deviceSnap.data() || {};
    const status = cleanString(deviceData.e2eeStatus);
    if (BLOCKED_DEVICE_STATUSES.has(status)) {
      continue;
    }

    const publicKey = cleanString(deviceData.publicKey);
    if (!publicKey) {
      continue;
    }

    const docRef = roomRef
      .collection("sessionKeys")
      .doc(sessionKeyDocId(userId, deviceId, keyId));
    const existing = await docRef.get();
    if (existing.exists) {
      continue;
    }

    batch.set(docRef, {
      userId,
      encryptedKey,
      keyId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    writeCount += 1;
  }

  if (writeCount > 0) {
    await batch.commit();
  }

  return {
    roomId,
    keyId,
    written: writeCount,
  };
});

module.exports = {
  sendEncryptedChatMessage,
  publishWrappedRoomKeys,
};
