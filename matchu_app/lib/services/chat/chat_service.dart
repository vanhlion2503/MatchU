import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoom(String roomId) {
    return _db.collection("chatRooms").doc(roomId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _db.collection("chatRooms").doc(roomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenChatRooms() {
    return _db
        .collection("chatRooms")
        .where("participants", arrayContains: uid)
        .orderBy("lastMessageAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenMessagesWithFallback(
    String roomId,
    String? tempRoomId,
  ) {
    final chatMessages = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("createdAt")
        .snapshots();

    if (tempRoomId == null) return chatMessages;

    final tempMessages = _db
        .collection("tempChats")
        .doc(tempRoomId)
        .collection("messages")
        .orderBy("createdAt")
        .snapshots();

    return chatMessages.asyncMap((chatSnap) async {
      if (chatSnap.docs.isNotEmpty) {
        return chatSnap; // ✅ migrate xong
      }

      final tempSnap = await tempMessages.first;
      return tempSnap; // ⚠️ fallback
    });
  }


  Future<void> sendMessage({
    required String roomId,
    required String text,
    String type = "text",
    String? replyToId,
    String? replyText,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final msgRef = roomRef.collection("messages").doc();

    final roomSnap = await roomRef.get();
    final participants = List<String>.from(roomSnap["participants"]);
    final otherUid = participants.firstWhere((e) => e != uid);

    final batch = _db.batch();

    // 1️⃣ message
    batch.set(msgRef, {
      "senderId": uid,
      "text": text,
      "type": type,
      "replyToId": replyToId,
      "replyText": replyText,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 2️⃣ CHAT ROOM METADATA (🔥 QUAN TRỌNG)
    batch.update(roomRef, {
      "lastMessage": text,
      "lastMessageType": type,
      "lastSenderId": uid,
      "lastMessageAt": FieldValue.serverTimestamp(),

      "unread.$otherUid": FieldValue.increment(1),
      "unread.$uid": 0,
    });

    await batch.commit();
  }


  Future<void> markAsRead(String roomId) async {
    await _db.collection("chatRooms").doc(roomId).update({
      "unread.$uid": 0,
    });
  }
}