import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/telepathy_question.dart';
import 'package:matchu_app/models/telepathy_result.dart';

class TelepathyService {
  TelepathyService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const Map<String, dynamic> _approvedSystemFields = {
    'status': 'approved',
    'blockedBy': null,
    'reason': null,
    'warning': false,
    'aiScore': null,
  };

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _db.collection('tempChats').doc(roomId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return _roomRef(roomId).snapshots();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  List<String> _participants(Map<String, dynamic> data) {
    final fromList = List<String>.from(data['participants'] ?? const []);
    if (fromList.length >= 2) return fromList;

    final userA = data['userA'];
    final userB = data['userB'];
    if (userA is String && userB is String && userA != userB) {
      return [userA, userB];
    }
    return fromList;
  }

  bool _allAccepted(Map<String, dynamic> game, List<String> participants) {
    if (participants.length < 2) return false;
    final consent = Map<String, dynamic>.from(game['consent'] ?? const {});
    return participants.every((uid) => consent[uid] == true);
  }

  bool _questionExists(Map<String, dynamic> game, String questionId) {
    final rawQuestions = game['questions'];
    if (rawQuestions is! List) return false;

    for (final item in rawQuestions) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map['id'] == questionId) return true;
    }
    return false;
  }

  bool _hasBothAnswersAtCurrentIndex(
    Map<String, dynamic> game,
    List<String> participants,
  ) {
    if (participants.length < 2) return false;

    final currentIndex = _asInt(game['currentQuestionIndex'], fallback: -1);
    if (currentIndex < 0) return false;

    final rawQuestions = game['questions'];
    if (rawQuestions is! List || currentIndex >= rawQuestions.length) {
      return false;
    }

    final q = rawQuestions[currentIndex];
    if (q is! Map) return false;
    final questionId = Map<String, dynamic>.from(q)['id'];
    if (questionId is! String || questionId.isEmpty) return false;

    final answers = Map<String, dynamic>.from(game['answers'] ?? const {});
    final answerMap = answers[questionId];
    if (answerMap is! Map) return false;
    final normalized = Map<String, dynamic>.from(answerMap);

    return participants.every((uid) => normalized[uid] is String);
  }

  Future<void> invite(String roomId) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final game = data['minigame'];
      final status = game is Map ? game['status'] : null;

      if (status == 'inviting') return;
      if (status == 'playing' || status == 'countdown') return;

      tx.update(ref, {
        'minigame.type': 'telepathy',
        'minigame.status': 'inviting',
        'minigame.invitedAt': FieldValue.serverTimestamp(),
        'minigame.consent': {},
        'minigame.cancelledBy': FieldValue.delete(),
        'minigame.cancelledAt': FieldValue.delete(),
        'minigame.finishedAt': FieldValue.delete(),
        'minigame.hookSent': FieldValue.delete(),
        'minigame.result': FieldValue.delete(),
        'minigame.questions': FieldValue.delete(),
        'minigame.answers': {},
        'minigame.currentQuestionIndex': 0,
        'minigame.questionStartedAt': FieldValue.delete(),
        'minigame.startedAt': FieldValue.delete(),
        'minigame.countdownStartedAt': FieldValue.delete(),
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

      final data = snap.data() ?? const <String, dynamic>{};
      final game = data['minigame'];
      final status = game is Map ? game['status'] : null;
      if (status != 'inviting') return;

      if (!accept) {
        tx.update(ref, {
          'minigame.status': 'cancelled',
          'minigame.cancelledBy': uid,
          'minigame.cancelledAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.update(ref, {'minigame.consent.$uid': true});
    });
  }

  Future<void> startCountdown(String roomId) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      final status = game['status'];
      if (status == 'countdown') return;
      if (status != 'inviting') return;

      final participants = _participants(data);
      if (!_allAccepted(game, participants)) return;

      tx.update(ref, {
        'minigame.status': 'countdown',
        'minigame.countdownStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> startGame({
    required String roomId,
    required List<TelepathyQuestion> questions,
  }) async {
    if (questions.isEmpty) return;

    final ref = _roomRef(roomId);
    final payload = questions.map((e) => e.toJson()).toList(growable: false);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      if (game['status'] != 'countdown') return;

      final participants = _participants(data);
      if (!_allAccepted(game, participants)) return;

      tx.update(ref, {
        'minigame.status': 'playing',
        'minigame.questions': payload,
        'minigame.currentQuestionIndex': 0,
        'minigame.answers': {},
        'minigame.questionStartedAt': FieldValue.serverTimestamp(),
        'minigame.startedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitAnswer({
    required String roomId,
    required String uid,
    required String questionId,
    required String option,
  }) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      if (game['status'] != 'playing') return;
      if (!_questionExists(game, questionId)) return;

      final answers = Map<String, dynamic>.from(game['answers'] ?? const {});
      final answerMap = Map<String, dynamic>.from(
        answers[questionId] ?? const {},
      );
      if (answerMap[uid] is String) return;

      tx.update(ref, {'minigame.answers.$questionId.$uid': option});
    });
  }

  Future<void> advanceQuestion(String roomId, {int? expectedIndex}) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      if (game['status'] != 'playing') return;

      final current = _asInt(game['currentQuestionIndex'], fallback: -1);
      if (current < 0) return;
      if (expectedIndex != null && expectedIndex != current) return;

      final questions = game['questions'];
      if (questions is! List) return;
      if (current + 1 >= questions.length) return;

      tx.update(ref, {
        'minigame.currentQuestionIndex': current + 1,
        'minigame.questionStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setRevealing(String roomId, {int? expectedIndex}) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      if (game['status'] != 'playing') return;

      final current = _asInt(game['currentQuestionIndex'], fallback: -1);
      if (current < 0) return;
      if (expectedIndex != null && current != expectedIndex) return;

      final participants = _participants(data);
      if (!_hasBothAnswersAtCurrentIndex(game, participants)) return;

      tx.update(ref, {'minigame.status': 'revealing'});
    });
  }

  Future<void> continueAfterReveal(String roomId, {int? expectedIndex}) async {
    final ref = _roomRef(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      if (game['status'] != 'revealing') return;

      final current = _asInt(game['currentQuestionIndex'], fallback: -1);
      if (current < 0) return;
      if (expectedIndex != null && current != expectedIndex) return;

      final questions = game['questions'];
      if (questions is! List) return;
      if (current + 1 >= questions.length) return;

      tx.update(ref, {
        'minigame.status': 'playing',
        'minigame.currentQuestionIndex': current + 1,
        'minigame.questionStartedAt': FieldValue.serverTimestamp(),
      });
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

      final data = snap.data() ?? const <String, dynamic>{};
      final rawGame = data['minigame'];
      if (rawGame is! Map) return;

      final game = Map<String, dynamic>.from(rawGame);
      final status = game['status'];

      // Ignore stale finish calls once server state already completed/cancelled.
      if (status == 'finished' || status == 'cancelled' || status == 'idle') {
        return;
      }

      final hookSent = game['hookSent'] == true;

      tx.update(ref, {
        'minigame.status': 'finished',
        'minigame.result': result.toJson(),
        'minigame.finishedAt': FieldValue.serverTimestamp(),
        'minigame.aiInsight': {
          'status': 'pending',
          'payload': aiPayload,
          'text': null,
          'tone': 'positive',
          'generatedAt': null,
        },
        if (!hookSent) 'minigame.hookSent': true,
      });

      if (!hookSent) {
        tx.set(ref.collection('messages').doc(), {
          'type': 'system',
          'systemCode': 'telepathy_hook',
          'text': hookMessage,
          'senderId': uid,
          ..._approvedSystemFields,
          'createdAt': FieldValue.serverTimestamp(),
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
    await _roomRef(roomId).collection('messages').add({
      'type': 'system',
      'systemCode': 'telepathy_cancelled',
      'text': text,
      'senderId': uid,
      'targetUid': otherUid,
      ..._approvedSystemFields,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
