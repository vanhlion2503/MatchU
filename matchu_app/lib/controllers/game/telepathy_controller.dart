import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/game/telepathy_question_bank.dart';
import 'package:matchu_app/models/telepathy_question.dart';
import 'package:matchu_app/controllers/game/telepathy_result_calculator.dart';
import 'package:matchu_app/models/telepathy_result.dart';

enum TelepathyStatus {
  idle,
  inviting,
  countdown,
  playing,
  revealing,
  finished,
  cancelled,
}

enum TelepathySubmitAction {
  accept,
  decline,
}

class TelepathyController extends GetxController{

  final String roomId;
  TelepathyController(this.roomId);

  final _db = FirebaseFirestore.instance;
  final uid = Get.find<AuthController>().user!.uid;

  final status = TelepathyStatus.idle.obs;
  final currentIndex = 0.obs;
  final remainingSeconds = _questionDurationSeconds.obs;
  final countdownSeconds = _countdownDurationSeconds.obs;

  final questions = <TelepathyQuestion>[].obs;
  final myAnswers = <String, String>{}.obs;
  final otherAnswers = <String, String>{}.obs;
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
  Timer? _timer;
  Timer? _countdownTimer;
  DateTime? _questionStartedAt;
  DateTime? _countdownStartedAt;
  int? _lastAdvanceIndex;
  String? _otherUid;
  bool? _isHost;
  bool _startingCountdown = false;
  DateTime? _lastFinishedAt;
  int _serverOffsetMs = 0;
  static const int _questionDurationSeconds = 15;
  static const int _countdownDurationSeconds = 3;
  static const int _questionLeadMs = 500;
  static const int _countdownLeadMs = 0;
  bool get isPlaying => status.value == TelepathyStatus.playing;

  @override
  void onInit() {
    super.onInit();
    _listenRoom();
  }

  void _listenRoom(){
    _sub = _db.collection("tempChats").doc(roomId).snapshots().listen((doc){
      final data = doc.data();
      if(data == null) return;

      _syncParticipants(data);

      final game = data["minigame"];
      if (game == null) {
        status.value = TelepathyStatus.idle;
        myConsent.value = false;
        otherConsent.value = false;
        cancelledBy.value = null;
        result.value = null;
        showResultOverlay.value = false;
        submittingAction.value = null;
        _lastFinishedAt = null;
        _startingCountdown = false;
        _lastAdvanceIndex = null;
        _stopTimers();
        return;
      }

      final nextStatus = TelepathyStatus.values.firstWhere(
        (e) => e.name == game["status"],
        orElse: () => TelepathyStatus.idle,
      );

      status.value = nextStatus;
      if (status.value != TelepathyStatus.inviting) {
        submittingAction.value = null;
      }

      if (status.value == TelepathyStatus.finished) {
        final finishedAt = _parseTimestamp(game["finishedAt"]);

        // 🔥 CHỈ MỞ OVERLAY – KHÔNG BAO GIỜ ĐÓNG Ở ĐÂY
        if (finishedAt != null && finishedAt != _lastFinishedAt) {
          showResultOverlay.value = true;
          _lastFinishedAt = finishedAt;
        }
      }


      if (status.value != TelepathyStatus.inviting) {
        _startingCountdown = false;
      }
      if (status.value != TelepathyStatus.playing) {
        _lastAdvanceIndex = null;
      }

      final consent = Map<String, dynamic>.from(game["consent"] ?? {});
      final prevOtherAccepted = otherConsent.value;

      myConsent.value = consent[uid] == true;
      otherConsent.value =_otherUid != null ? consent[_otherUid!] == true : false;

      if (!prevOtherAccepted && otherConsent.value) {
        opponentJustAccepted.value = true;

        // auto tắt sau 600ms
        Future.delayed(const Duration(milliseconds: 600), () {
          opponentJustAccepted.value = false;
        });
      }

      cancelledBy.value = game["cancelledBy"];

      if (status.value == TelepathyStatus.inviting) {
        invitedAt.value = _parseTimestamp(game["invitedAt"]);
        if (myConsent.value &&
            otherConsent.value &&
            _isHost == true &&
            !_startingCountdown) {

          _startingCountdown = true;

          // 🔥 1. START COUNTDOWN NGAY (LOCAL)
          final localNow = DateTime.now();
          _startCountdownLocal(localNow);

          // 🔄 2. SYNC LÊN FIRESTORE (KHÔNG ĐỢI)
          _db.collection("tempChats").doc(roomId).update({
            "minigame.status": "countdown",
            "minigame.countdownStartedAt": FieldValue.serverTimestamp(),
          });
        }

        _stopTimers();
        return;
      }

      if (status.value == TelepathyStatus.countdown) {
        _syncCountdown(game);
        return;
      }

      if (status.value == TelepathyStatus.playing) {
        _syncGame(game);
        _ensureQuestionTimer();
        return;
      }

      if (status.value == TelepathyStatus.finished) {
        _syncResult(game);
        final ai = game["aiInsight"];
        if (ai is Map) {
          aiInsightStatus.value = ai["status"];
          aiInsightText.value = ai["text"];
        } else {
          aiInsightStatus.value = null;
          aiInsightText.value = null;
        }
        _stopTimers();
        return;
      }

      _stopTimers();
    });
  }

  void _syncGame(Map game){
    currentIndex.value = game["currentQuestionIndex"] ?? 0;

    final rawQuestions = game["questions"];
    if (rawQuestions is List) {
      questions.assignAll(
        rawQuestions
            .map((e) => TelepathyQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } else {
      questions.clear();
    }

    final startedAt = _parseTimestamp(game["questionStartedAt"]);
    if (startedAt != null) {
      _questionStartedAt = startedAt;
      _updateServerOffset(startedAt);
      _updateQuestionRemaining();
    } else {
      _questionStartedAt = null;
      remainingSeconds.value = _questionDurationSeconds;
    }

    final answers = Map<String, dynamic>.from(game["answers"] ?? {});
    myAnswers.clear();
    otherAnswers.clear();

    for (final entry in answers.entries) {
      final answerMap = Map<String, dynamic>.from(entry.value ?? {});
      for (final answer in answerMap.entries) {
        final value = answer.value;
        if (value is! String) continue;

        if (answer.key == uid) {
          myAnswers[entry.key] = value;
        } else {
          otherAnswers[entry.key] = value;
        }
      }
    }

    _maybeAdvanceOnBothAnswered();
  }

  Future<void> invite() async {
    final ref = _db.collection("tempChats").doc(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final game = data["minigame"] as Map<String, dynamic>?;
      final status = game?["status"];

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

  Future<void> respond(bool accept) async {
    final action =
        accept ? TelepathySubmitAction.accept : TelepathySubmitAction.decline;

    if (submittingAction.value != null) return; // ⛔ chặn double click

    submittingAction.value = action;

    final ref = _db.collection("tempChats").doc(roomId);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final game = snap["minigame"];
        if (game?["status"] != "inviting") return;

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

      if (!accept) {
        await _sendDeclineMessage();
      }
    } finally {
      // ❗ KHÔNG reset
      // UI sẽ biến mất khi status đổi
    }
  }

  Future<void> startGame() async {
    if (_isHost != true) return;
    
    // SỬA Ở ĐÂY: Dùng hàm pickSmartMix mới
    final qs = TelepathyQuestionBank.pickSmartMix();

    await _db.collection("tempChats").doc(roomId).update({
      "minigame.status": "playing",
      "minigame.questions": qs.map((e) => e.toJson()).toList(),
      "minigame.currentQuestionIndex": 0,
      "minigame.answers": {},
      "minigame.questionStartedAt": FieldValue.serverTimestamp(),
      "minigame.startedAt": FieldValue.serverTimestamp(),
    });
    _startingCountdown = false;
  }

  void _ensureQuestionTimer() {
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _updateQuestionRemaining();
      if (remainingSeconds.value <= 0 &&
          _isHost == true &&
          _lastAdvanceIndex != currentIndex.value) {
        _lastAdvanceIndex = currentIndex.value;
        await next();
      }
    });
  }

  void _updateQuestionRemaining() {
    if (_questionStartedAt == null) {
      remainingSeconds.value = _questionDurationSeconds;
      return;
    }

    final effectiveStart =
        _questionStartedAt!.add(const Duration(milliseconds: _questionLeadMs));
    final elapsedMs = _serverNow()
        .difference(effectiveStart)
        .inMilliseconds;
    final remainingMs = (_questionDurationSeconds * 1000) - elapsedMs;
    final remaining = (remainingMs / 1000).ceil();
    remainingSeconds.value =
        remaining.clamp(0, _questionDurationSeconds);
  }

  Future<void> answer(String option) async {
    if (currentIndex.value >= questions.length) return;
    final q = questions[currentIndex.value];

    await _db.collection("tempChats").doc(roomId).update({
      "minigame.answers.${q.id}.$uid": option,
    });
  }

  Future<void> next() async {
    if (_isHost != true) return;

    if (currentIndex.value + 1 >= questions.length) {
      await finish();
    } else {
      await _db.collection("tempChats").doc(roomId).update({
        "minigame.currentQuestionIndex": FieldValue.increment(1),
        "minigame.questionStartedAt": FieldValue.serverTimestamp(),
      });
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

    final ref = _db.collection("tempChats").doc(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final game = Map<String, dynamic>.from(snap["minigame"] ?? {});
      final hookSent = game["hookSent"] == true;

      tx.update(ref, {
        "minigame.status": "finished",
        "minigame.result": result.toJson(),
        "minigame.finishedAt": FieldValue.serverTimestamp(),

        // 🔥 AI PART
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
          "text": _buildHookMessage(result),
          "senderId": uid,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
    });
  }


  Map<String, dynamic> _buildAiPayload({
    required TelepathyResult result,
  }){
    final items = <Map<String, dynamic>>[];

    for(final q in questions){

      final my = myAnswers[q.id];
      final other = otherAnswers[q.id];

      if(my == null || other == null) continue;
      items.add({
        "question": q.text,
        "category": q.category.name,
        "me": my,
        "other": other,
        "same": my == other,
      });
    }
    return{
      "score": result.score,
      "level": result.level.name,
      "questions": items,
    };
  }

  void _syncParticipants(Map<String, dynamic> data) {
    final userA = data["userA"];
    final userB = data["userB"];
    if (userA is! String || userB is! String) return;

    _isHost = userA == uid;
    _otherUid = _isHost == true ? userB : userA;
  }

  Future<void> _startCountdown() async {
    if (_isHost != true) return;

    await _db.collection("tempChats").doc(roomId).update({
      "minigame.status": "countdown",
      "minigame.countdownStartedAt": FieldValue.serverTimestamp(),
    });
  }

  void _syncCountdown(Map game) {
    final startedAt = _parseTimestamp(game["countdownStartedAt"]);
    if (startedAt != null) {
      _countdownStartedAt = startedAt;
      _updateServerOffset(startedAt);
      _updateCountdownRemaining();
    } else {
      _countdownStartedAt = null;
      countdownSeconds.value = _countdownDurationSeconds;
    }

    _ensureCountdownTimer();
  }

  void _ensureCountdownTimer() {
    if (_countdownTimer != null) return;

    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) async {
      _updateCountdownRemaining();

      if (countdownSeconds.value <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        if (_isHost == true) {
          await startGame();
        }
      }
    });
  }

  void _updateCountdownRemaining() {
    if (_countdownStartedAt == null) {
      countdownSeconds.value = _countdownDurationSeconds;
      return;
    }

    final effectiveStart =
        _countdownStartedAt!.add(const Duration(milliseconds: _countdownLeadMs));
    final elapsedMs = _serverNow()
        .difference(effectiveStart)
        .inMilliseconds;
    final remainingMs = (_countdownDurationSeconds * 1000) - elapsedMs;
    final remaining = (remainingMs / 1000).ceil();
    countdownSeconds.value =
        remaining.clamp(0, _countdownDurationSeconds);
  }

  DateTime _serverNow() {
    return DateTime.now().add(Duration(milliseconds: _serverOffsetMs));
  }

  void _updateServerOffset(DateTime serverTime) {
    final localNow = DateTime.now().millisecondsSinceEpoch;
    _serverOffsetMs = serverTime.millisecondsSinceEpoch - localNow;
  }

  void _stopTimers() {
    _timer?.cancel();
    _timer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _syncResult(Map game) {
    final raw = game["result"];
    if (raw is Map) {
      result.value = TelepathyResult.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } else {
      result.value = null;
    }
  }

  void _maybeAdvanceOnBothAnswered() {
    if (_isHost != true) return;
    if (currentIndex.value >= questions.length) return;

    final q = questions[currentIndex.value];
    final my = myAnswers[q.id];
    final other = otherAnswers[q.id];

    if (my == null || other == null) return;
    if (_lastAdvanceIndex == currentIndex.value) return;

    _lastAdvanceIndex = currentIndex.value;

    // 1️⃣ REVEAL
    _db.collection("tempChats").doc(roomId).update({
      "minigame.status": "revealing",
    });

    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (_isHost != true) return;

      // 🔥 NẾU LÀ CÂU CUỐI → FINISH NGAY
      if (currentIndex.value + 1 >= questions.length) {
        await finish();
        return;
      }

      // 🔥 CHƯA HẾT → SANG CÂU TIẾP
      await _db.collection("tempChats").doc(roomId).update({
        "minigame.status": "playing",
        "minigame.currentQuestionIndex": FieldValue.increment(1),
        "minigame.questionStartedAt": FieldValue.serverTimestamp(),
      });
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
    if (_otherUid == null) return;

    await _db
        .collection("tempChats")
        .doc(roomId)
        .collection("messages")
        .add({
      "type": "system",
      "systemCode": "telepathy_cancelled",
      "text": "Bạn ấy muốn trò chuyện thêm chút nữa trước khi chơi!",
      "senderId": uid,
      "targetUid": _otherUid,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }

  void _startCountdownLocal(DateTime startedAt) {
    _countdownStartedAt = startedAt;
    _updateServerOffset(startedAt);
    _updateCountdownRemaining();
    _ensureCountdownTimer();
  }

  @override
  void onClose() {
    _sub?.cancel();
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.onClose();
  }
}

