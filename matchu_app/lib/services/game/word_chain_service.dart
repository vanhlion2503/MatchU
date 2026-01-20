import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class WordChainService {
  final _db = FirebaseFirestore.instance;
  final _random = Random();

  static const List<String> _seedWords = [
    'mưa rào',
    'kiếm tiền',
    'mây trời',
    'đường phố',
    'hoa sữa',
    'gió mát',
    'trăng sao',
    'bình yên',
    'nắng vàng',
    'mộng mơ',
    'tình bạn',
    'đêm khuya',
    'sáng sớm',
  ];


  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _db.collection("tempChats").doc(roomId);
  }

  // ================= INVITE FLOW =================
  Future<void> invite(String roomId) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;

      if (status == "inviting" || status == "playing") return;

      final participants = List<String>.from(data?["participants"] ?? []);
      if (participants.length < 2) return;

      final hearts = {
        for (final id in participants) id: 3,
      };
      final sosUsed = {
        for (final id in participants) id: false,
      };

      tx.update(ref, {
        "minigames.wordChain.status": "inviting",
        "minigames.wordChain.invitedAt": FieldValue.serverTimestamp(),
        "minigames.wordChain.consent": {},
        "minigames.wordChain.countdownStartedAt": FieldValue.delete(),
        "minigames.wordChain.currentWord": "",
        "minigames.wordChain.turnUid": "",
        "minigames.wordChain.remainingSeconds": 15,
        "minigames.wordChain.usedWords": [],
        "minigames.wordChain.winnerUid": FieldValue.delete(),
        "minigames.wordChain.hearts": hearts,
        "minigames.wordChain.sosUsed": sosUsed,
        "minigames.wordChain.startedAt": FieldValue.delete(),
        "minigames.wordChain.cancelledBy": FieldValue.delete(),
        "minigames.wordChain.cancelledAt": FieldValue.delete(),
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
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "inviting") return;

      if (!accept) {
        tx.update(ref, {
          "minigames.wordChain.status": "idle",
          "minigames.wordChain.consent": {},
          "minigames.wordChain.countdownStartedAt": FieldValue.delete(),
          "minigames.wordChain.cancelledBy": uid,
          "minigames.wordChain.cancelledAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(ref, {
        "minigames.wordChain.consent.$uid": true,
      });
    });
  }

  Future<void> startCountdown(String roomId) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "inviting") return;

      final participants = List<String>.from(data?["participants"] ?? []);
      if (participants.length < 2) return;

      final consent = Map<String, dynamic>.from(game?["consent"] ?? {});
      final allAccepted = participants.every((id) => consent[id] == true);
      if (!allAccepted) return;

      tx.update(ref, {
        "minigames.wordChain.status": "countdown",
        "minigames.wordChain.countdownStartedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> startGame(String roomId) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "countdown") return;

      final participants = List<String>.from(data?["participants"] ?? []);
      if (participants.length < 2) return;

      final consent = Map<String, dynamic>.from(game?["consent"] ?? {});
      final allAccepted = participants.every((id) => consent[id] == true);
      if (!allAccepted) return;

      final starter = participants[_random.nextInt(participants.length)];
      final seed = _randomSeedWord();
      final hearts = {
        for (final id in participants) id: 3,
      };
      final sosUsed = {
        for (final id in participants) id: false,
      };

      tx.update(ref, {
        "minigames.wordChain.status": "playing",
        "minigames.wordChain.currentWord": seed,
        "minigames.wordChain.turnUid": starter,
        "minigames.wordChain.remainingSeconds": 15,
        "minigames.wordChain.usedWords": [seed],
        "minigames.wordChain.hearts": hearts,
        "minigames.wordChain.sosUsed": sosUsed,
        "minigames.wordChain.winnerUid": FieldValue.delete(),
        "minigames.wordChain.startedAt": FieldValue.serverTimestamp(),
        "minigames.wordChain.countdownStartedAt": FieldValue.delete(),
      });
    });
  }

  // ================= VALIDATION =================
  bool validateWord({
    required String input,
    required String prevWord,
    required List<String> usedWords,
  }) {
    final clean = input.trim();
    final parts = clean.split(RegExp(r'\s+'));

    // Điều kiện 1: đúng 2 tiếng
    if (parts.length != 2) return false;

    // Điều kiện 3: không trùng
    if (usedWords.contains(clean)) return false;

    if (prevWord.trim().isEmpty) return true;

    // Điều kiện 3.2: nối từ strict
    final prevLast = prevWord.split(RegExp(r'\s+')).last;
    if (parts.first != prevLast) return false;

    // Điều kiện 2 (từ điển) → TODO: Cloud Function
    return true;
  }

  // ================= SUBMIT ĐÚNG =================
  Future<void> submitCorrectWord(
    String roomId,
    String uid,
    String word,
  ) async {
    final ref = _db.collection("tempChats").doc(roomId);
    final snap = await ref.get();

    final participants = List<String>.from(snap["participants"]);
    final nextUid = participants.firstWhere((e) => e != uid);

    await ref.update({
      "minigames.wordChain.currentWord": word,
      "minigames.wordChain.usedWords": FieldValue.arrayUnion([word]),
      "minigames.wordChain.turnUid": nextUid,
      "minigames.wordChain.remainingSeconds": 15,
      "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // ================= TIMEOUT → LOSE HEART =================
  Future<void> loseHeartOnly(String roomId, String uid) async {
    final ref = _db.collection("tempChats").doc(roomId);
    final snap = await ref.get();

    final hearts = Map<String, int>.from(
      snap["minigames"]["wordChain"]["hearts"],
    );

    hearts[uid] = hearts[uid]! - 1;

    if (hearts[uid]! <= 0) {
      // 🏁 GAME OVER
      await ref.update({
        "minigames.wordChain.status": "finished",
        "minigames.wordChain.winnerUid":
            hearts.keys.firstWhere((e) => e != uid),
      });
      return;
    }

    await ref.update({
      "minigames.wordChain.hearts": hearts,
    });
  }

  Future<void> handleTimeout({
    required String roomId,
    required String uid,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "playing") return;

      final participants = List<String>.from(data?["participants"] ?? []);
      if (participants.length < 2) return;
      final otherUid = participants.firstWhere((e) => e != uid);

      final hearts = Map<String, int>.from(game?["hearts"] ?? {});
      final nextHearts = (hearts[uid] ?? 0) - 1;
      hearts[uid] = nextHearts;

      if (nextHearts <= 0) {
        tx.update(ref, {
          "minigames.wordChain.status": "finished",
          "minigames.wordChain.winnerUid": otherUid,
          "minigames.wordChain.hearts": hearts,
          "minigames.wordChain.remainingSeconds": 0,
          "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      final seed = _randomSeedWord();
      tx.update(ref, {
        "minigames.wordChain.currentWord": seed,
        "minigames.wordChain.usedWords": [seed],
        "minigames.wordChain.turnUid": otherUid,
        "minigames.wordChain.remainingSeconds": 15,
        "minigames.wordChain.hearts": hearts,
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  // ================= TIMER =================
  Future<void> resetTimer(String roomId) async {
    await _db.collection("tempChats").doc(roomId).update({
      "minigames.wordChain.remainingSeconds": 15,
    });
  }

  Future<void> updateTimer(String roomId, int seconds) async {
    await _db.collection("tempChats").doc(roomId).update({
      "minigames.wordChain.remainingSeconds": seconds,
    });
  }

  // ================= SOS =================
  Future<void> useSOS(String roomId, String uid) async {
    await _db.collection("tempChats").doc(roomId).update({
      "minigames.wordChain.sosUsed.$uid": true,
    });
    // TODO: auto-generate valid word
  }

  String _randomSeedWord() {
    return _seedWords[_random.nextInt(_seedWords.length)];
  }
}

