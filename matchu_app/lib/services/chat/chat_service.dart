import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/services/security/message_crypto_service.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String get uid => _auth.currentUser!.uid;

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoom(String roomId) {
    return _db.collection("chatRooms").doc(roomId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _db.collection("chatRooms").doc(roomId).snapshots();
  }

  Stream<List<ChatRoomModel>> listenChatRooms() {
    return _db
        .collection("chatRooms")
        .where("participants", arrayContains: uid)
        .orderBy("lastMessageAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatRoomModel.fromDoc).toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessagesWithFallback(
    String roomId,
    String? tempRoomId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> chatQuery = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("createdAt", descending: true)
        .limit(limit);

    if (startAfter != null) {
      chatQuery = chatQuery.startAfterDocument(startAfter);
    }

    final chatMessages = chatQuery.snapshots();

    if (tempRoomId == null) return chatMessages;

    Query<Map<String, dynamic>> tempQuery = _db
        .collection("tempChats")
        .doc(tempRoomId)
        .collection("messages")
        .orderBy("createdAt", descending: true)
        .limit(limit);

    if (startAfter != null) {
      tempQuery = tempQuery.startAfterDocument(startAfter);
    }

    final tempMessages = tempQuery.snapshots();

    return chatMessages.asyncMap((chatSnap) async {
      if (chatSnap.docs.isNotEmpty) {
        return chatSnap; // ✅ migrate xong
      }

      final tempSnap = await tempMessages.first;
      return tempSnap; // ⚠️ fallback
    });
  }

  Future<void> setTyping({
    required String roomId,
    required bool isTyping,
  }) async {
    await _db.collection("chatRooms").doc(roomId).update({
      "typing.$uid": isTyping,
    });
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
    String type = "text",
    String? replyToId,
    String? replyText,
    int keyId = 0,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final msgRef = roomRef.collection("messages").doc();

    final roomSnap = await roomRef.get();
    final participants = List<String>.from(roomSnap["participants"]);
    final otherUid = participants.firstWhere((e) => e != uid);

    final encrypted = await MessageCryptoService.encrypt(
      roomId: roomId,
      plaintext: text,
      keyId: keyId,
    );

    final batch = _db.batch();

    // 1️⃣ message
    batch.set(msgRef, {
      "senderId": uid,
      "ciphertext": encrypted["ciphertext"],
      "iv": encrypted["iv"],
      "keyId": keyId,
      "type": type,
      "notificationPreview": _buildNotificationPreview(text),
      "replyToId": replyToId,
      "replyText": replyText,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 2️⃣ CHAT ROOM METADATA (🔥 QUAN TRỌNG)
    batch.update(roomRef, {
      "lastMessage": "🔐 Tin nhắn được mã hóa",
      "lastMessageType": "encrypted",

      "lastMessageCipher": encrypted["ciphertext"],
      "lastMessageIv": encrypted["iv"],
      "lastMessageKeyId": keyId,

      "lastSenderId": uid,
      "lastMessageAt": FieldValue.serverTimestamp(),
      "deletedFor.$otherUid": FieldValue.delete(),
      "unread.$otherUid": FieldValue.increment(1),
      "unread.$uid": 0,
    });

    await batch.commit();
  }

  Future<void> sendImageMessage({
    required String roomId,
    required File file,
    String? replyToId,
    String? replyText,
    void Function(double progress)? onUploadProgress,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final msgRef = roomRef.collection("messages").doc();

    final roomSnap = await roomRef.get();
    final participants = List<String>.from(roomSnap["participants"]);
    final otherUid = participants.firstWhere((e) => e != uid);

    final imagePath = "chatRooms/$roomId/images/${msgRef.id}.jpg";
    final storageRef = _storage.ref(imagePath);

    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: "image/jpeg", cacheControl: "no-store"),
    );

    StreamSubscription<TaskSnapshot>? uploadSub;
    if (onUploadProgress != null) {
      uploadSub = uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onUploadProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    try {
      await uploadTask;
      onUploadProgress?.call(1.0);
    } finally {
      await uploadSub?.cancel();
    }

    final batch = _db.batch();

    batch.set(msgRef, {
      "senderId": uid,
      "text": "Ảnh",
      "type": "image",
      "notificationPreview": _buildImageNotificationPreview(),
      "imagePath": imagePath,
      "viewOnce": true,
      "viewedBy": {},
      "replyToId": replyToId,
      "replyText": replyText,
      "createdAt": FieldValue.serverTimestamp(),
    });

    batch.update(roomRef, {
      "lastMessage": "Ảnh",
      "lastMessageType": "image",
      "lastMessageCipher": FieldValue.delete(),
      "lastMessageIv": FieldValue.delete(),
      "lastMessageKeyId": 0,
      "lastSenderId": uid,
      "lastMessageAt": FieldValue.serverTimestamp(),
      "deletedFor.$otherUid": FieldValue.delete(),
      "unread.$otherUid": FieldValue.increment(1),
      "unread.$uid": 0,
    });

    await batch.commit();
  }

  Future<void> markAsRead(String roomId) async {
    await _db.collection("chatRooms").doc(roomId).update({"unread.$uid": 0});
  }

  Future<void> setPinned(String roomId, bool value) async {
    await _db.collection("chatRooms").doc(roomId).update({
      "pinned.$uid": value ? true : FieldValue.delete(),
    });
  }

  Future<void> hideRoom(String roomId) async {
    await _db.collection("chatRooms").doc(roomId).update({
      "deletedFor.$uid": true,
    });
  }

  Stream<int> listenTotalUnread() {
    return _db
        .collection("chatRooms")
        .where("participants", arrayContains: uid)
        .snapshots()
        .map((snap) {
          int total = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final unread = data["unread"]?[uid] ?? 0;
            total += unread as int;
          }
          return total;
        });
  }

  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String reactionId,
  }) async {
    final msgRef = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .doc(messageId);

    final snap = await msgRef.get();
    final data = snap.data();
    if (data == null) return;

    final current = data["reactions"]?[uid];

    if (current == reactionId) {
      await msgRef.update({"reactions.$uid": FieldValue.delete()});
    } else {
      await msgRef.update({"reactions.$uid": reactionId});
    }
  }

  Future<void> updateMessage({
    required String roomId,
    required String messageId,
    required Map<String, dynamic> messageUpdate,
    Map<String, dynamic>? roomUpdate,
  }) async {
    final msgRef = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .doc(messageId);

    if (roomUpdate == null) {
      await msgRef.update(messageUpdate);
      return;
    }

    final roomRef = _db.collection("chatRooms").doc(roomId);
    final batch = _db.batch();
    batch.update(msgRef, messageUpdate);
    batch.update(roomRef, roomUpdate);
    await batch.commit();
  }

  Future<String> getOrCreateRoom(String otherUid) async {
    final myUid = uid;

    final query =
        await _db
            .collection("chatRooms")
            .where("participants", arrayContains: myUid)
            .get();

    for (final doc in query.docs) {
      final participants = List<String>.from(doc["participants"]);
      if (participants.contains(otherUid)) {
        return doc.id;
      }
    }

    // ❌ chưa có → tạo mới
    final roomRef = _db.collection("chatRooms").doc();

    await roomRef.set({
      "participants": [myUid, otherUid],
      "createdAt": FieldValue.serverTimestamp(),
      "lastMessage": "",
      "lastMessageAt": FieldValue.serverTimestamp(),
      "typing": {},
      "unread": {myUid: 0, otherUid: 0},
    });

    return roomRef.id;
  }

  String _buildNotificationPreview(String text) {
    const maxLength = 160;
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return "Tin nhan moi";
    }
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return "${normalized.substring(0, maxLength).trimRight()}...";
  }

  String _buildImageNotificationPreview() {
    return "Da gui mot anh";
  }
}
