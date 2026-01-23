import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class WordChainService {
  final _db = FirebaseFirestore.instance;
  final _random = Random();
  static const int _rewardMaxDeclines = 2;

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

      if (status == "inviting" || status == "playing" || status == "reward") {
        return;
      }

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
        "minigames.wordChain.reward": FieldValue.delete(),
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
          "minigames.wordChain.reward": FieldValue.delete(),
          "minigames.wordChain.cancelledBy": uid,
          "minigames.wordChain.cancelledAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(ref, {
        "minigames.wordChain.consent.$uid": true,
      });

      final participants = List<String>.from(data?["participants"] ?? []);
      if (participants.length < 2) return;

      final consent = Map<String, dynamic>.from(game?["consent"] ?? {});
      consent[uid] = true;
      final allAccepted = participants.every((id) => consent[id] == true);
      if (!allAccepted) return;

      tx.update(ref, {
        "minigames.wordChain.status": "countdown",
        "minigames.wordChain.countdownStartedAt": FieldValue.serverTimestamp(),
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
        "minigames.wordChain.reward": FieldValue.delete(),
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
      await ref.update({
        "minigames.wordChain.status": "reward",
        "minigames.wordChain.winnerUid":
            hearts.keys.firstWhere((e) => e != uid),
        "minigames.wordChain.reward": _rewardState(
          phase: "asking",
          askingStartedAt: FieldValue.serverTimestamp(),
        ),
        "minigames.wordChain.remainingSeconds": 0,
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
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
          "minigames.wordChain.status": "reward",
          "minigames.wordChain.winnerUid": otherUid,
          "minigames.wordChain.reward": _rewardState(
            phase: "asking",
            askingStartedAt: FieldValue.serverTimestamp(),
          ),
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

  // ================= REWARD PHASE =================
  Future<void> submitRewardQuestion({
    required String roomId,
    required String uid,
    required String question,
    String? presetId,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "reward") return;

      final winnerUid = game?["winnerUid"];
      if (winnerUid != uid) return;

      final reward = Map<String, dynamic>.from(game?["reward"] ?? {});
      if (reward["phase"] != "asking") return;

      final cleanQuestion = question.trim();
      if (cleanQuestion.isEmpty) return;

      tx.update(ref, {
        "minigames.wordChain.reward": _rewardState(
          phase: "answering",
          question: cleanQuestion,
          questionPresetId: presetId,
          declineCount: 0,
          askedAt: FieldValue.serverTimestamp(),
          answeringStartedAt: FieldValue.serverTimestamp(),
        ),
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitRewardAnswer({
    required String roomId,
    required String uid,
    required String answer,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "reward") return;

      final winnerUid = game?["winnerUid"];
      if (winnerUid == null || winnerUid == uid) return;

      final reward = Map<String, dynamic>.from(game?["reward"] ?? {});
      if (reward["phase"] != "answering") return;

      final cleanAnswer = answer.trim();
      if (cleanAnswer.isEmpty) return;

      final rawDeclines = reward["declineCount"];
      final declineCount = rawDeclines is int
          ? rawDeclines
          : rawDeclines is num
              ? rawDeclines.toInt()
              : 0;

      final askedAt = reward["askedAt"];
      final question = reward["question"]?.toString();
      final questionPresetId = reward["questionPresetId"]?.toString();

      if (declineCount >= _rewardMaxDeclines) {
        tx.update(ref, {
          "minigames.wordChain.status": "finished",
          "minigames.wordChain.reward": _rewardState(
            phase: "done",
            question: question,
            questionPresetId: questionPresetId,
            answer: cleanAnswer,
            declineCount: declineCount,
            askedAt: askedAt,
            answeredAt: FieldValue.serverTimestamp(),
            completedAt: FieldValue.serverTimestamp(),
            autoAcceptedReason: "max_declines",
          ),
          "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(ref, {
        "minigames.wordChain.reward": _rewardState(
          phase: "reviewing",
          question: question,
          questionPresetId: questionPresetId,
          answer: cleanAnswer,
          declineCount: declineCount,
          askedAt: askedAt,
          answeredAt: FieldValue.serverTimestamp(),
          reviewStartedAt: FieldValue.serverTimestamp(),
        ),
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reviewRewardAnswer({
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
      if (status != "reward") return;

      final winnerUid = game?["winnerUid"];
      if (winnerUid != uid) return;

      final reward = Map<String, dynamic>.from(game?["reward"] ?? {});
      if (reward["phase"] != "reviewing") return;

      final rawDeclines = reward["declineCount"];
      final declineCount = rawDeclines is int
          ? rawDeclines
          : rawDeclines is num
              ? rawDeclines.toInt()
              : 0;

      final askedAt = reward["askedAt"];
      final answeredAt = reward["answeredAt"];
      final question = reward["question"]?.toString();
      final questionPresetId = reward["questionPresetId"]?.toString();
      final answer = reward["answer"]?.toString();

      if (accept || declineCount >= _rewardMaxDeclines) {
        if (accept) {
          final cleanQuestion = question?.trim() ?? '';
          final cleanAnswer = answer?.trim() ?? '';
          if (cleanQuestion.isNotEmpty && cleanAnswer.isNotEmpty) {
            tx.set(
              ref.collection("messages").doc(),
              {
                "type": "system",
                "systemCode": "word_chain_reward",
                "text": "Câu hỏi: $cleanQuestion\nCâu trả lời: $cleanAnswer",
                "senderId": uid,
                "createdAt": FieldValue.serverTimestamp(),
              },
            );
          }
        }
        tx.update(ref, {
          "minigames.wordChain.status": "finished",
          "minigames.wordChain.reward": _rewardState(
            phase: "done",
            question: question,
            questionPresetId: questionPresetId,
            answer: answer,
            declineCount: declineCount,
            askedAt: askedAt,
            answeredAt: answeredAt,
            completedAt: FieldValue.serverTimestamp(),
            autoAcceptedReason:
                accept ? null : "max_declines",
          ),
          "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(ref, {
        "minigames.wordChain.reward": _rewardState(
          phase: "answering",
          question: question,
          questionPresetId: questionPresetId,
          declineCount: declineCount + 1,
          askedAt: askedAt,
          answeringStartedAt: FieldValue.serverTimestamp(),
        ),
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> autoAcceptReward({
    required String roomId,
    required String reason,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "reward") return;

      final reward = Map<String, dynamic>.from(game?["reward"] ?? {});
      if (reward["phase"] != "reviewing") return;

      final rawDeclines = reward["declineCount"];
      final declineCount = rawDeclines is int
          ? rawDeclines
          : rawDeclines is num
              ? rawDeclines.toInt()
              : 0;

      tx.update(ref, {
        "minigames.wordChain.status": "finished",
        "minigames.wordChain.reward": _rewardState(
          phase: "done",
          question: reward["question"]?.toString(),
          questionPresetId: reward["questionPresetId"]?.toString(),
          answer: reward["answer"]?.toString(),
          declineCount: declineCount,
          askedAt: reward["askedAt"],
          answeredAt: reward["answeredAt"],
          completedAt: FieldValue.serverTimestamp(),
          autoAcceptedReason: reason,
        ),
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> exitReward({
    required String roomId,
    required String uid,
    required String reason,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data();
      final game = data?["minigames"]?["wordChain"];
      final status = game is Map ? game["status"] : null;
      if (status != "reward") return;

      final reward = Map<String, dynamic>.from(game?["reward"] ?? {});
      final phase = reward["phase"];
      if (phase != "asking" && phase != "answering") return;

      final winnerUid = game?["winnerUid"]?.toString();
      if (reason == "winner_left" && (winnerUid != uid || phase != "asking")) {
        return;
      }
      if (reason == "ask_timeout" && phase != "asking") return;
      if (reason == "answer_timeout" && phase != "answering") return;

      final rawDeclines = reward["declineCount"];
      final declineCount = rawDeclines is int
          ? rawDeclines
          : rawDeclines is num
              ? rawDeclines.toInt()
              : 0;

      final askedAt = reward["askedAt"];
      final answeredAt = reward["answeredAt"];
      final question = reward["question"]?.toString();
      final questionPresetId = reward["questionPresetId"]?.toString();
      final answer = reward["answer"]?.toString();

      tx.update(ref, {
        "minigames.wordChain.status": "finished",
        "minigames.wordChain.reward": _rewardState(
          phase: "done",
          question: question,
          questionPresetId: questionPresetId,
          answer: answer,
          declineCount: declineCount,
          askedAt: askedAt,
          answeredAt: answeredAt,
          completedAt: FieldValue.serverTimestamp(),
          autoAcceptedReason: reason,
        ),
        "minigames.wordChain.updatedAt": FieldValue.serverTimestamp(),
      });

      final participants = List<String>.from(data?["participants"] ?? []);
      final targetUid = _rewardExitTargetUid(
        reason: reason,
        winnerUid: winnerUid,
        participants: participants,
      );

      tx.set(
        ref.collection("messages").doc(),
        {
          "type": "system",
          "systemCode": "word_chain_exit",
          "text": _rewardExitMessage(reason),
          "senderId": uid,
          "targetUid": targetUid,
          "createdAt": FieldValue.serverTimestamp(),
        },
      );
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

  Map<String, dynamic> _rewardState({
    required String phase,
    String? question,
    String? questionPresetId,
    String? answer,
    int declineCount = 0,
    dynamic askingStartedAt,
    dynamic answeringStartedAt,
    dynamic askedAt,
    dynamic answeredAt,
    dynamic reviewStartedAt,
    String? autoAcceptedReason,
    dynamic completedAt,
  }) {
    return {
      "phase": phase,
      "question": question,
      "questionPresetId": questionPresetId,
      "answer": answer,
      "declineCount": declineCount,
      "askingStartedAt": askingStartedAt,
      "answeringStartedAt": answeringStartedAt,
      "askedAt": askedAt,
      "answeredAt": answeredAt,
      "reviewStartedAt": reviewStartedAt,
      "autoAcceptedReason": autoAcceptedReason,
      "completedAt": completedAt,
    };
  }

  String _randomSeedWord() {
    return _seedWords[_random.nextInt(_seedWords.length)];
  }

  String _rewardExitMessage(String reason) {
    switch (reason) {
      case 'ask_timeout':
        return 'Đối phương đã không đặt câu hỏi và đã thoát khỏi Word Chain.';
      case 'answer_timeout':
        return 'Đối phương đã không trả lời và đã thoát khỏi Word Chain.';
      case 'winner_left':
        return 'Đối phương đã thoát khỏi Word Chain.';
      default:
        return 'Đối phương đã thoát khỏi Word Chain.';
    }
  }

  String? _rewardExitTargetUid({
    required String reason,
    required String? winnerUid,
    required List<String> participants,
  }) {
    if (winnerUid == null) return null;
    if (participants.length < 2) return null;

    if (reason == 'answer_timeout') {
      return winnerUid;
    }
    if (reason == 'ask_timeout' || reason == 'winner_left') {
      for (final uid in participants) {
        if (uid != winnerUid) return uid;
      }
    }
    return null;
  }
}
