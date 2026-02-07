import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_timers.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_question_bank.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_result_calculator.dart';
import 'package:matchu_app/models/telepathy_question.dart';
import 'package:matchu_app/models/telepathy_result.dart';
import 'package:matchu_app/services/game/telepathy_service.dart';

enum TelepathyStatus {
  idle,
  inviting,
  countdown,
  playing,
  revealing,
  finished,
  cancelled,
}

enum TelepathySubmitAction { accept, decline }

class TelepathyController extends GetxController {
  final String roomId;
  TelepathyController(this.roomId);

  final TelepathyService _service = TelepathyService();
  final uid = Get.find<AuthController>().user!.uid;

  final status = TelepathyStatus.idle.obs;
  final currentIndex = 0.obs;
  final remainingSeconds = TelepathyTimers.questionDurationSeconds.obs;
  final countdownSeconds = TelepathyTimers.countdownDurationSeconds.obs;

  final questions = <TelepathyQuestion>[].obs;
  final myAnswers = <String, String>{}.obs;
  final otherAnswers = <String, String>{}.obs;
  final _localPendingAnswers = <String, String>{}.obs;
  final myConsent = false.obs;
  final otherConsent = false.obs;
  final cancelledBy = RxnString();
  final result = Rxn<TelepathyResult>();
  final showResultOverlay = false.obs;
  final submittingAction = Rxn<TelepathySubmitAction>();
  final opponentJustAccepted = false.obs;
  final aiInsightText = RxnString();
  final aiInsightStatus = RxnString();
  final invitedAt = Rxn<DateTime>();

  StreamSubscription? _sub;
  int? _lastAdvanceIndex;
  int? _lastRevealIndex;
  String? _otherUid;
  bool? _isHost;
  bool _startingCountdown = false;
  DateTime? _lastFinishedAt;
  late final TelepathyTimers _timers;
  Timer? _revealFallbackTimer;
  bool get isPlaying => status.value == TelepathyStatus.playing;

  String? selectedAnswerFor(String questionId) {
    return myAnswers[questionId] ?? _localPendingAnswers[questionId];
  }

  bool hasAnsweredQuestion(String questionId) {
    return selectedAnswerFor(questionId) != null;
  }

  bool isAnswerPending(String questionId) {
    return !myAnswers.containsKey(questionId) &&
        _localPendingAnswers.containsKey(questionId);
  }

  @override
  void onInit() {
    super.onInit();
    _timers = TelepathyTimers(
      remainingSeconds: remainingSeconds,
      countdownSeconds: countdownSeconds,
      onQuestionTimeout: _handleQuestionTimeout,
      onCountdownComplete: _handleCountdownComplete,
    );
    _listenRoom();
  }

  void _listenRoom() {
    _sub = _service.listenRoom(roomId).listen((doc) {
      final data = doc.data();
      if (data == null) return;

      _syncParticipants(data);

      final rawGame = data["minigame"];
      if (rawGame is! Map) {
        _resetGameState();
        return;
      }

      _syncGameState(Map<String, dynamic>.from(rawGame));
    });
  }

  TelepathyStatus _parseStatus(dynamic raw) {
    if (raw is! String) return TelepathyStatus.idle;
    return TelepathyStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TelepathyStatus.idle,
    );
  }

  void _syncGameState(Map<String, dynamic> game) {
    final nextStatus = _parseStatus(game["status"]);
    status.value = nextStatus;

    if (nextStatus != TelepathyStatus.inviting) {
      submittingAction.value = null;
      invitedAt.value = null;
      opponentJustAccepted.value = false;
      _startingCountdown = false;
    }

    if (nextStatus != TelepathyStatus.playing) {
      _lastAdvanceIndex = null;
    }

    if (nextStatus != TelepathyStatus.revealing) {
      _revealFallbackTimer?.cancel();
      _revealFallbackTimer = null;
    }

    if (nextStatus != TelepathyStatus.finished) {
      showResultOverlay.value = false;
      result.value = null;
      aiInsightStatus.value = null;
      aiInsightText.value = null;
    }

    _syncConsent(game);
    cancelledBy.value = game["cancelledBy"];

    switch (nextStatus) {
      case TelepathyStatus.inviting:
        _handleInviting(game);
        return;
      case TelepathyStatus.countdown:
        _handleCountdown(game);
        return;
      case TelepathyStatus.playing:
        _handlePlaying(game);
        return;
      case TelepathyStatus.revealing:
        _handleRevealing();
        return;
      case TelepathyStatus.finished:
        _handleFinished(game);
        return;
      case TelepathyStatus.cancelled:
      case TelepathyStatus.idle:
        _handleInactive();
        return;
    }
  }

  void _handleInviting(Map<String, dynamic> game) {
    invitedAt.value = _parseTimestamp(game["invitedAt"]);
    _timers.stopQuestionTimer();

    if (myConsent.value &&
        otherConsent.value &&
        _isHost == true &&
        !_startingCountdown) {
      _startingCountdown = true;
      _timers.startLocalCountdown(DateTime.now());
      _service.startCountdown(roomId);
    }

    if (!_startingCountdown) {
      _timers.stopCountdownTimer();
    }
  }

  void _handleCountdown(Map<String, dynamic> game) {
    _timers.stopQuestionTimer();
    _timers.syncCountdown(_parseTimestamp(game["countdownStartedAt"]));
    _timers.ensureCountdownTimer();
  }

  void _handlePlaying(Map<String, dynamic> game) {
    _timers.stopCountdownTimer();
    _syncGame(game);
    _timers.ensureQuestionTimer();
  }

  void _handleRevealing() {
    _timers.stopQuestionTimer();
    _scheduleRevealAdvanceFallback();
  }

  void _handleFinished(Map<String, dynamic> game) {
    _syncResult(game);
    final ai = game["aiInsight"];
    if (ai is Map) {
      aiInsightStatus.value = ai["status"];
      aiInsightText.value = ai["text"];
    } else {
      aiInsightStatus.value = null;
      aiInsightText.value = null;
    }

    final finishedAt = _parseTimestamp(game["finishedAt"]);
    if (finishedAt != null && finishedAt != _lastFinishedAt) {
      showResultOverlay.value = true;
      _lastFinishedAt = finishedAt;
    }

    _timers.stopAll();
  }

  void _handleInactive() {
    _timers.reset();
    _clearRoundData();
    myConsent.value = false;
    otherConsent.value = false;
    _lastRevealIndex = null;
    _revealFallbackTimer?.cancel();
    _revealFallbackTimer = null;
  }

  void _syncConsent(Map<String, dynamic> game) {
    final consent = Map<String, dynamic>.from(game["consent"] ?? {});
    final prevOtherAccepted = otherConsent.value;

    myConsent.value = consent[uid] == true;
    otherConsent.value =
        _otherUid != null ? consent[_otherUid!] == true : false;

    if (!prevOtherAccepted && otherConsent.value) {
      opponentJustAccepted.value = true;

      Future.delayed(const Duration(milliseconds: 600), () {
        opponentJustAccepted.value = false;
      });
    }
  }

  void _resetGameState() {
    status.value = TelepathyStatus.idle;
    myConsent.value = false;
    otherConsent.value = false;
    cancelledBy.value = null;
    result.value = null;
    showResultOverlay.value = false;
    submittingAction.value = null;
    opponentJustAccepted.value = false;
    aiInsightText.value = null;
    aiInsightStatus.value = null;
    invitedAt.value = null;
    _lastFinishedAt = null;
    _startingCountdown = false;
    _lastAdvanceIndex = null;
    _lastRevealIndex = null;
    _revealFallbackTimer?.cancel();
    _revealFallbackTimer = null;
    _clearRoundData();
    _timers.reset();
  }

  void _clearRoundData() {
    currentIndex.value = 0;
    questions.clear();
    myAnswers.clear();
    otherAnswers.clear();
    _localPendingAnswers.clear();
  }

  void _scheduleRevealAdvanceFallback() {
    if (_isHost != true) return;
    if (questions.isEmpty) return;

    final index = currentIndex.value;
    if (index < 0 || index >= questions.length) return;

    final question = questions[index];
    final my = myAnswers[question.id];
    final other = otherAnswers[question.id];
    if (my == null || other == null) return;

    if (_lastRevealIndex == index) return;
    _lastRevealIndex = index;
    _continueFromRevealingNow(index);
  }

  void _continueFromRevealingNow(int index) {
    Future<void>(() async {
      if (_isHost != true) return;
      if (status.value != TelepathyStatus.revealing) return;
      if (currentIndex.value != index) return;

      try {
        if (index + 1 >= questions.length) {
          await finish();
        } else {
          await _service.continueAfterReveal(roomId, expectedIndex: index);
        }
      } catch (_) {
        _lastRevealIndex = null;
      }
    });
  }

  Future<void> _handleQuestionTimeout() async {
    if (_isHost != true) return;
    if (status.value != TelepathyStatus.playing) return;
    if (_lastAdvanceIndex == currentIndex.value) return;
    _lastAdvanceIndex = currentIndex.value;
    await next();
  }

  Future<void> _handleCountdownComplete() async {
    if (_isHost != true) return;
    if (status.value != TelepathyStatus.countdown) return;
    await startGame();
  }

  void _syncGame(Map<String, dynamic> game) {
    final rawIndex = game["currentQuestionIndex"];
    if (rawIndex is int) {
      currentIndex.value = rawIndex;
    } else if (rawIndex is num) {
      currentIndex.value = rawIndex.toInt();
    } else {
      currentIndex.value = 0;
    }

    final rawQuestions = game["questions"];
    if (rawQuestions is List) {
      final parsed = <TelepathyQuestion>[];
      for (final item in rawQuestions) {
        if (item is Map) {
          parsed.add(
            TelepathyQuestion.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      questions.assignAll(parsed);
    } else {
      questions.clear();
    }

    _timers.syncQuestion(_parseTimestamp(game["questionStartedAt"]));

    final rawAnswers = game["answers"];
    myAnswers.clear();
    otherAnswers.clear();
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final answerMap = entry.value;
        if (answerMap is! Map) continue;
        final entries = Map<String, dynamic>.from(answerMap);
        for (final answer in entries.entries) {
          final value = answer.value;
          if (value is! String) continue;

          if (answer.key == uid) {
            myAnswers[entry.key] = value;
          } else if (_otherUid != null && answer.key == _otherUid) {
            otherAnswers[entry.key] = value;
          }
        }
      }
    }

    // Keep local tap feedback until server write is observed, then clear it.
    final acknowledged = <String>[];
    for (final questionId in _localPendingAnswers.keys) {
      if (myAnswers.containsKey(questionId)) {
        acknowledged.add(questionId);
      }
    }
    for (final questionId in acknowledged) {
      _localPendingAnswers.remove(questionId);
    }

    // Drop stale pending entries if question no longer exists in this round.
    final validQuestionIds = questions.map((q) => q.id).toSet();
    _localPendingAnswers.removeWhere((questionId, _) {
      return !validQuestionIds.contains(questionId);
    });

    _maybeAdvanceOnBothAnswered();
  }

  Future<void> invite() async {
    await _service.invite(roomId);
  }

  Future<void> respond(bool accept) async {
    final action =
        accept ? TelepathySubmitAction.accept : TelepathySubmitAction.decline;

    if (submittingAction.value != null) return;

    submittingAction.value = action;

    try {
      await _service.respond(roomId: roomId, uid: uid, accept: accept);

      if (!accept) {
        await _sendDeclineMessage();
      }
    } catch (_) {
      submittingAction.value = null;
      rethrow;
    }
  }

  Future<void> startGame() async {
    if (_isHost != true) return;

    final qs = TelepathyQuestionBank.pickSmartMix();

    await _service.startGame(roomId: roomId, questions: qs);
    _startingCountdown = false;
  }

  Future<void> answer(String option) async {
    if (status.value != TelepathyStatus.playing) return;
    if (currentIndex.value >= questions.length) return;

    final q = questions[currentIndex.value];
    if (hasAnsweredQuestion(q.id)) return;

    // Optimistic lock for instant UI feedback, avoids double taps/race.
    _localPendingAnswers[q.id] = option;

    try {
      await _service.submitAnswer(
        roomId: roomId,
        uid: uid,
        questionId: q.id,
        option: option,
      );
    } catch (_) {
      _localPendingAnswers.remove(q.id);
      rethrow;
    }
  }

  Future<void> next() async {
    if (_isHost != true) return;

    if (currentIndex.value + 1 >= questions.length) {
      await finish();
    } else {
      await _service.advanceQuestion(roomId, expectedIndex: currentIndex.value);
    }
  }

  Future<void> finish() async {
    if (_isHost != true) return;

    final result = TelepathyResultCalculator.calculate(
      questions: questions,
      myAnswers: myAnswers,
      otherAnswers: otherAnswers,
    );

    final aiPayload = _buildAiPayload(result: result);

    await _service.finishGame(
      roomId: roomId,
      uid: uid,
      result: result,
      aiPayload: aiPayload,
      hookMessage: _buildHookMessage(result),
    );
  }

  Map<String, dynamic> _buildAiPayload({required TelepathyResult result}) {
    final items = <Map<String, dynamic>>[];

    for (final q in questions) {
      final my = myAnswers[q.id];
      final other = otherAnswers[q.id];

      if (my == null || other == null) continue;
      items.add({
        "question": q.text,
        "category": q.category.name,
        "me": my,
        "other": other,
        "same": my == other,
      });
    }
    return {
      "score": result.score,
      "level": result.level.name,
      "questions": items,
    };
  }

  void _syncParticipants(Map<String, dynamic> data) {
    final userA = data["userA"];
    final userB = data["userB"];
    if (userA is! String || userB is! String) {
      _isHost = null;
      _otherUid = null;
      return;
    }

    _isHost = userA == uid;
    _otherUid = _isHost == true ? userB : userA;
  }

  void _syncResult(Map<String, dynamic> game) {
    final raw = game["result"];
    if (raw is Map) {
      result.value = TelepathyResult.fromJson(Map<String, dynamic>.from(raw));
    } else {
      result.value = null;
    }
  }

  void _maybeAdvanceOnBothAnswered() {
    if (_isHost != true) return;
    if (currentIndex.value >= questions.length) return;

    final revealIndex = currentIndex.value;
    final q = questions[revealIndex];
    final my = myAnswers[q.id];
    final other = otherAnswers[q.id];

    if (my == null || other == null) return;
    if (_lastAdvanceIndex == revealIndex) return;

    _lastAdvanceIndex = revealIndex;
    _advanceToNextQuestionNow(revealIndex);
  }

  void _advanceToNextQuestionNow(int index) {
    Future<void>(() async {
      if (_isHost != true) return;
      if (status.value != TelepathyStatus.playing) return;
      if (currentIndex.value != index) return;

      try {
        if (index + 1 >= questions.length) {
          await finish();
        } else {
          await _service.advanceQuestion(roomId, expectedIndex: index);
        }
      } catch (_) {
        _lastAdvanceIndex = null;
      }
    });
  }

  String _buildHookMessage(TelepathyResult result) {
    final same = List<Map<String, dynamic>>.from(
      result.highlight["same"] ?? [],
    );
    final diff = List<Map<String, dynamic>>.from(
      result.highlight["diff"] ?? [],
    );

    switch (result.level) {
      case TelepathyLevel.high:
        final answer = same.isNotEmpty ? same.first["answer"] : null;
        if (answer is String && answer.isNotEmpty) {
          return "Wow! ${result.score}% tương đồng! "
              "Hai bạn là tri kỷ thật lực đó 😳 "
              "Ờ mà khoan… cả 2 đều chọn '$answer', "
              "hẹn hò có dự định gì chưa? 😉";
        }
        return "Wow! ${result.score}% tương đồng! Hai bạn là tri kỷ thật lực đó 😳";

      case TelepathyLevel.medium:
        final me = diff.isNotEmpty ? diff.first["me"] : null;
        final other = diff.isNotEmpty ? diff.first["other"] : null;
        if (me is String && other is String) {
          return "Hợp nhau ${result.score}%. Khá ổn đấy chứ! 🤝 "
              "Nhưng mà này… "
              "bạn thích '$me' còn người kia lại thích '$other'. "
              "Hai bạn tính sao về vụ này? 😄";
        }
        return "Hợp nhau ${result.score}%. Khá ổn đấy chứ! 🤝";

      case TelepathyLevel.low:
        final other = diff.isNotEmpty ? diff.first["other"] : null;
        if (other is String) {
          return "Chỉ ${result.score}% thôi à 😅 "
              "Hai cực nam châm trái dấu thường hút nhau mạnh lắm đấy! 🧲 "
              "Thử hỏi vì sao người kia lại chọn '$other' xem nào? 😉";
        }
        return "Chỉ ${result.score}% thôi 😅 Đôi khi trái dấu lại hút nhau mạnh!";
    }
  }

  Future<void> _sendDeclineMessage() async {
    final otherUid = _otherUid;
    if (otherUid == null) return;

    await _service.sendDeclineMessage(
      roomId: roomId,
      uid: uid,
      otherUid: otherUid,
      text: "Bạn ấy muốn trò chuyện thêm một chút nữa trước khi chơi",
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }

  @override
  void onClose() {
    _sub?.cancel();
    _timers.dispose();
    _revealFallbackTimer?.cancel();
    super.onClose();
  }
}
