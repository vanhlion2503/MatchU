import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/telepathy_question.dart';
import 'package:matchu_app/models/telepathy_result.dart';

class TelepathyService {
  TelepathyService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _db.collection("tempChats").doc(roomId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _roomRef(roomId).snapshots();
  }

  Future<void> invite(String roomId) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigame"];
      final status = game is Map ? game["status"] : null;

      if (status == "inviting") return;
      if (status == "playing" || status == "countdown") return;

      tx.update(ref, {
        "minigame.type": "telepathy",
        "minigame.status": "inviting",
        "minigame.invitedAt": FieldValue.serverTimestamp(),
        "minigame.consent": {},
        "minigame.cancelledBy": FieldValue.delete(),
        "minigame.cancelledAt": FieldValue.delete(),
        "minigame.finishedAt": FieldValue.delete(),
        "minigame.hookSent": FieldValue.delete(),
        "minigame.result": FieldValue.delete(),
        "minigame.questions": FieldValue.delete(),
        "minigame.answers": {},
        "minigame.currentQuestionIndex": 0,
        "minigame.questionStartedAt": FieldValue.delete(),
        "minigame.startedAt": FieldValue.delete(),
        "minigame.countdownStartedAt": FieldValue.delete(),
      });
    });
  }

  Future<void> respond({
    required String roomId,
    required String uid,
    required bool accept,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigame"];
      final status = game is Map ? game["status"] : null;
      if (status != "inviting") return;

      if (!accept) {
        tx.update(ref, {
          "minigame.status": "cancelled",
          "minigame.cancelledBy": uid,
          "minigame.cancelledAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(ref, {
        "minigame.consent.$uid": true,
      });
    });
  }

  Future<void> startCountdown(String roomId) async {
    await _roomRef(roomId).update({
      "minigame.status": "countdown",
      "minigame.countdownStartedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> startGame({
    required String roomId,
    required List<TelepathyQuestion> questions,
  }) async {
    await _roomRef(roomId).update({
      "minigame.status": "playing",
      "minigame.questions": questions.map((e) => e.toJson()).toList(),
      "minigame.currentQuestionIndex": 0,
      "minigame.answers": {},
      "minigame.questionStartedAt": FieldValue.serverTimestamp(),
      "minigame.startedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitAnswer({
    required String roomId,
    required String uid,
    required String questionId,
    required String option,
  }) async {
    await _roomRef(roomId).update({
      "minigame.answers.$questionId.$uid": option,
    });
  }

  Future<void> advanceQuestion(String roomId) async {
    await _roomRef(roomId).update({
      "minigame.currentQuestionIndex": FieldValue.increment(1),
      "minigame.questionStartedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRevealing(String roomId) async {
    await _roomRef(roomId).update({
      "minigame.status": "revealing",
    });
  }

  Future<void> continueAfterReveal(String roomId) async {
    await _roomRef(roomId).update({
      "minigame.status": "playing",
      "minigame.currentQuestionIndex": FieldValue.increment(1),
      "minigame.questionStartedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> finishGame({
    required String roomId,
    required String uid,
    required TelepathyResult result,
    required Map<String, dynamic> aiPayload,
    required String hookMessage,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigame"];
      final hookSent = game is Map && game["hookSent"] == true;

      tx.update(ref, {
        "minigame.status": "finished",
        "minigame.result": result.toJson(),
        "minigame.finishedAt": FieldValue.serverTimestamp(),
        "minigame.aiInsight": {
          "status": "pending",
          "payload": aiPayload,
          "text": null,
          "tone": "positive",
          "generatedAt": null,
        },
        if (!hookSent) "minigame.hookSent": true,
      });

      if (!hookSent) {
        tx.set(ref.collection("messages").doc(), {
          "type": "system",
          "systemCode": "telepathy_hook",
          "text": hookMessage,
          "senderId": uid,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> sendDeclineMessage({
    required String roomId,
    required String uid,
    required String otherUid,
    required String text,
  }) async {
    await _roomRef(roomId).collection("messages").add({
      "type": "system",
      "systemCode": "telepathy_cancelled",
      "text": text,
      "senderId": uid,
      "targetUid": otherUid,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
