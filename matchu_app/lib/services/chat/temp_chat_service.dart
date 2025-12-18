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

      if(!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;

      if (uid != data["userA"] && uid != data["userB"]) return;

      final isA = data["userA"] == uid;

      await ref.update({
        isA ? "userALiked" : "userBLiked": value,
      });
    }

  Future<void> endRoom({
    required String roomId,
    required String uid,
    required String reason,
  }) async {
    await _db.collection("tempChats").doc(roomId).update({
      "status": "ended",
      "endedBy": uid,
      "endedReason": reason,
      "endedAt": FieldValue.serverTimestamp(),
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
}