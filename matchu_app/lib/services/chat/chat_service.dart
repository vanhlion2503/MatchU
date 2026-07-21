import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/services/security/message_crypto_service.dart';

class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    PostRestrictionService? restrictionService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _restrictionService = restrictionService ?? PostRestrictionService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final PostRestrictionService _restrictionService;

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
    DateTime? clearedAfter,
  }) {
    Query<Map<String, dynamic>> chatQuery = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages");

    if (clearedAfter != null) {
      chatQuery = chatQuery.where(
        "createdAt",
        isGreaterThan: Timestamp.fromDate(clearedAfter),
      );
    }

    chatQuery = chatQuery.orderBy("createdAt", descending: true).limit(limit);

    if (startAfter != null) {
      chatQuery = chatQuery.startAfterDocument(startAfter);
    }

    final chatMessages = chatQuery.snapshots();

    if (tempRoomId == null) return chatMessages;

    Query<Map<String, dynamic>> tempQuery = _db
        .collection("tempChats")
        .doc(tempRoomId)
        .collection("messages");

    if (clearedAfter != null) {
      tempQuery = tempQuery.where(
        "createdAt",
        isGreaterThan: Timestamp.fromDate(clearedAfter),
      );
    }

    tempQuery = tempQuery.orderBy("createdAt", descending: true).limit(limit);

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
    String? clientMessageId,
    int keyId = 0,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final msgRef = roomRef.collection("messages").doc();

    final roomSnap = await roomRef.get();
    final participants = List<String>.from(roomSnap["participants"]);
    final otherUid = participants.firstWhere((e) => e != uid);
    await _ensureCanMessage(otherUid);

    final encrypted = await MessageCryptoService.encrypt(
      roomId: roomId,
      plaintext: text,
      keyId: keyId,
    );

    if (await _sendMessageWithCallable(
      roomId: roomId,
      encrypted: encrypted,
      type: type,
      replyToId: replyToId,
      replyText: replyText,
      clientMessageId: clientMessageId,
      keyId: keyId,
    )) {
      return;
    }

    final batch = _db.batch();

    // 1️⃣ message
    batch.set(msgRef, {
      "senderId": uid,
      "ciphertext": encrypted["ciphertext"],
      "iv": encrypted["iv"],
      "keyId": keyId,
      "type": type,
      if (type == 'post_share')
        "notificationPreview": "Đã chia sẻ một bài viết",
      "replyToId": replyToId,
      "replyText": replyText,
      if (clientMessageId != null) "clientMessageId": clientMessageId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 2️⃣ CHAT ROOM METADATA (🔥 QUAN TRỌNG)
    batch.update(roomRef, {
      "lastMessage": "🔐 Tin nhắn được mã hóa",
      "lastMessageType": type == 'post_share' ? type : "encrypted",

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

  Future<bool> _sendMessageWithCallable({
    required String roomId,
    required Map<String, String> encrypted,
    required String type,
    required String? replyToId,
    required String? replyText,
    required String? clientMessageId,
    required int keyId,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendEncryptedChatMessage');
      await callable.call(<String, dynamic>{
        'roomId': roomId,
        'ciphertext': encrypted['ciphertext'],
        'iv': encrypted['iv'],
        'keyId': keyId,
        'type': type,
        'replyToId': replyToId,
        'replyText': replyText,
        'clientMessageId': clientMessageId,
      });
      return true;
    } on FirebaseFunctionsException catch (error) {
      // Keep old clients usable while the new function is being deployed.
      if (error.code == 'not-found' ||
          error.code == 'unimplemented' ||
          type == 'post_share' && error.code == 'invalid-argument') {
        return false;
      }
      rethrow;
    }
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
    await _ensureCanMessage(otherUid);

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

  Future<void> sendVoiceMessage({
    required String roomId,
    required File file,
    required String fileName,
    required int durationMs,
    String? replyToId,
    String? replyText,
    void Function(double progress)? onUploadProgress,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final msgRef = roomRef.collection("messages").doc();

    final roomSnap = await roomRef.get();
    final participants = List<String>.from(roomSnap["participants"]);
    final otherUid = participants.firstWhere((e) => e != uid);
    await _ensureCanMessage(otherUid);

    final voicePath =
        "chatRooms/$roomId/voices/${msgRef.id}.${_fileExtension(fileName)}";
    final storageRef = _storage.ref(voicePath);

    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(
        contentType: _voiceContentType(fileName),
        cacheControl: "no-store",
      ),
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

    final voiceUrl = await storageRef.getDownloadURL();
    final batch = _db.batch();

    batch.set(msgRef, {
      "senderId": uid,
      "text": "Ghi âm",
      "type": "voice",
      "notificationPreview": "Đã gửi một ghi âm",
      "voiceUrl": voiceUrl,
      "voicePath": voicePath,
      "voiceDurationMs": durationMs,
      "replyToId": replyToId,
      "replyText": replyText,
      "createdAt": FieldValue.serverTimestamp(),
    });

    batch.update(roomRef, {
      "lastMessage": "Ghi âm",
      "lastMessageType": "voice",
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

  Future<void> markAsUnread(String roomId) async {
    await _db.collection("chatRooms").doc(roomId).update({"unread.$uid": 1});
  }

  Future<void> setPinned(String roomId, bool value) async {
    await _db.collection("chatRooms").doc(roomId).update({
      "pinned.$uid": value ? true : FieldValue.delete(),
    });
  }

  Future<void> hideRoom(String roomId) async {
    await _db.collection("chatRooms").doc(roomId).update({
      "deletedFor.$uid": true,
      "clearedAt.$uid": FieldValue.serverTimestamp(),
      "unread.$uid": 0,
      "pinned.$uid": FieldValue.delete(),
    });
  }

  Stream<int> listenTotalUnread() {
    final currentUid = uid;
    final roomStream =
        _db
            .collection("chatRooms")
            .where("participants", arrayContains: currentUid)
            .snapshots();
    final blockedStream = _restrictionService.watchBlockedUserIds();

    late final StreamController<int> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomSub;
    StreamSubscription<Set<String>>? blockedSub;
    QuerySnapshot<Map<String, dynamic>>? latestRooms;
    Set<String>? latestBlockedIds;

    void emitIfReady() {
      final rooms = latestRooms;
      final blockedIds = latestBlockedIds;
      if (rooms == null || blockedIds == null || controller.isClosed) return;

      controller.add(
        calculateTotalUnreadFromRooms(
          rooms: rooms.docs.map((doc) => doc.data()),
          currentUid: currentUid,
          blockedUserIds: blockedIds,
        ),
      );
    }

    controller = StreamController<int>(
      onListen: () {
        roomSub = roomStream.listen((snapshot) {
          latestRooms = snapshot;
          emitIfReady();
        }, onError: controller.addError);
        blockedSub = blockedStream.listen((blockedIds) {
          latestBlockedIds = blockedIds;
          emitIfReady();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await Future.wait([
          if (roomSub != null) roomSub!.cancel(),
          if (blockedSub != null) blockedSub!.cancel(),
        ]);
      },
    );

    return controller.stream.distinct();
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
    await _ensureCanMessage(otherUid);

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

  Future<void> _ensureCanMessage(String otherUid) async {
    final normalizedOtherUid = otherUid.trim();
    if (normalizedOtherUid.isEmpty) return;

    if (await _restrictionService.hasBlockRelationship(normalizedOtherUid)) {
      throw StateError(
        'Kh\u00F4ng th\u1EC3 nh\u1EAFn tin v\u00EC m\u1ED9t trong hai ng\u01B0\u1EDDi \u0111\u00E3 ch\u1EB7n ng\u01B0\u1EDDi c\u00F2n l\u1EA1i.',
      );
    }
  }

  String _buildImageNotificationPreview() {
    return "Đã gửi một ảnh";
  }

  String _fileExtension(String fileName) {
    final normalized = fileName.split('?').first.toLowerCase();
    final parts = normalized.split('.');
    if (parts.length < 2) return 'm4a';
    final extension = parts.last.trim();
    return extension.isEmpty ? 'm4a' : extension;
  }

  String _voiceContentType(String fileName) {
    switch (_fileExtension(fileName)) {
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'audio/mp4';
    }
  }
}

int calculateTotalUnreadFromRooms({
  required Iterable<Map<String, dynamic>> rooms,
  required String currentUid,
  Set<String> blockedUserIds = const <String>{},
}) {
  var total = 0;
  for (final room in rooms) {
    final participants = List<String>.from(
      room["participants"] ?? const <String>[],
    );
    final otherUid = participants.firstWhere(
      (participant) => participant != currentUid,
      orElse: () => '',
    );
    if (otherUid.isNotEmpty && blockedUserIds.contains(otherUid)) continue;

    final unreadMap = room["unread"];
    final unreadValue = unreadMap is Map ? unreadMap[currentUid] : null;
    final unread = unreadValue is num ? unreadValue.toInt() : 0;
    if (unread > 0) total += unread;
  }
  return total;
}
