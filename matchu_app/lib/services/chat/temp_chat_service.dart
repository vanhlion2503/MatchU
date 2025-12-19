import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';



class TempChatService {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final snap = await _db.collection("tempChats").doc(roomId).get();
    return snap.data()!;
  }

  Stream<DocumentSnapshot> listenRoom(String roomId){
    return _db.collection("tempChats").doc(roomId).snapshots();
  }

  Stream<QuerySnapshot> listenMessages(String roomId) {
    return _db
        .collection("tempChats")
        .doc(roomId)
        .collection("messages")
        .orderBy("createdAt")
        .snapshots();
  }

  Future<void> sendMessages(String roomId, TempMessageModel messages) async{
    await _db.collection("tempChats").doc(roomId).collection("messages").add(messages.toJson());
  }

  Future<void> setLike({
    required String roomId,
    required String uid,
    required bool value,
  }) async {
    final ref = _db.collection("tempChats").doc(roomId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final isA = data["userA"] == uid;
    final otherUid = isA ? data["userB"] : data["userA"];

    await ref.update({
      isA ? "userALiked" : "userBLiked": value,
    });

    // ❤️ SYSTEM MESSAGE CHỈ CHO ĐỐI PHƯƠNG
    if (value == true) {
      await ref.collection("messages").add({
        "type": "system",
        "systemCode": "like",
        "text": "❤️ Đối phương đã thích bạn",
        "senderId": uid,
        "targetUid": otherUid,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> endRoom({
    required String roomId,
    required String uid,
    required String reason,
  }) async {
    final ref = _db.collection("tempChats").doc(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      if (data["status"] != "active") return;

      // 1️⃣ Update room
      tx.update(ref, {
        "status": "ended",
        "endedBy": uid,
        "endedReason": reason,
        "endedAt": FieldValue.serverTimestamp(),
      });

      // 2️⃣ System message
      tx.set(
        ref.collection("messages").doc(),
        {
          "type": "system",
          "event": "ended",
          "text": reason == "left"
              ? "Người kia đã rời phòng"
              : "Cuộc trò chuyện đã kết thúc",
          "senderId": uid,
          "createdAt": FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<String> convertToPermanent(String roomId) async {
    final snap =
        await _db.collection("tempChats").doc(roomId).get();

    final ref = _db.collection("chatRooms").doc();
    await ref.set({
      "participants": snap["participants"],
      "createdAt": FieldValue.serverTimestamp(),
    });

    await _db.collection("tempChats").doc(roomId).update({
      "status": "converted",
    });

    return ref.id;
  }

  Future<void> sendSystemMessage({
    required String roomId,
    required String text,
    required String code,
    required String senderId,
  }) async {
    await _db
        .collection("tempChats")
        .doc(roomId)
        .collection("messages")
        .add({
      "type": "system",
      "systemCode": code,
      "text": text,
      "senderId": senderId,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTyping({
    required String roomId,
    required String uid,
    required bool typing,
  }) async {
    final ref = _db.collection("tempChats").doc(roomId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;

    final isA = data["userA"] == uid;

    await ref.update({
      "typing.${isA ? 'userA' : 'userB'}": typing,
    });
  }
}