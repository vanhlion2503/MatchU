import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/word_chain.dart';
import 'package:matchu_app/services/game/word_chain_service.dart';


enum WordChainSubmitAction {
  accept,
  decline,
}

class WordChainController extends GetxController {
  final String roomId;
  WordChainController(this.roomId);

  final _db = FirebaseFirestore.instance;
  final uid = Get.find<AuthController>().user!.uid;
  final service = WordChainService();

  // ===== GAME STATE =====
  final status = WordChainStatus.idle.obs;
  final currentWord = "".obs;
  final turnUid = "".obs;
  final remainingSeconds = 15.obs;
  final countdownSeconds = 3.obs;

  final hearts = <String, int>{}.obs;
  final usedWords = <String>[].obs;
  final sosUsed = <String, bool>{}.obs;

  final winnerUid = RxnString();
  final myConsent = false.obs;
  final otherConsent = false.obs;
  final invitedAt = Rxn<DateTime>();
  final submittingAction = Rxn<WordChainSubmitAction>();
  final opponentJustAccepted = false.obs;

  StreamSubscription? _sub;
  Timer? _timer;
  Timer? _countdownTimer;
  DateTime? _countdownStartedAt;
  DateTime? _localCountdownStartedAt;
  String? _otherUid;
  bool? _isHost;
  bool _startingCountdown = false;
  bool _startingGame = false;
  static const int _countdownTotalSeconds = 3;

  // ================= INIT =================
  @override
  void onInit() {
    super.onInit();
    _listenRoom();
  }

  // ================= LISTEN FIRESTORE =================
  void _listenRoom() {
    _sub = _db.collection("tempChats").doc(roomId).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;

      _syncParticipants(data);

      final rawGame = data["minigames"]?["wordChain"];
      if (rawGame is! Map) {
        _resetGameState();
        return;
      }

      final game = Map<String, dynamic>.from(rawGame);
      final nextStatus = _parseStatus(game["status"]);
      status.value = nextStatus;

      if (nextStatus != WordChainStatus.inviting) {
        submittingAction.value = null;
        invitedAt.value = null;
        opponentJustAccepted.value = false;
        _startingCountdown = false;
      }

      currentWord.value = game["currentWord"] ?? "";
      turnUid.value = game["turnUid"] ?? "";
      remainingSeconds.value = game["remainingSeconds"] ?? 15;
      winnerUid.value = game["winnerUid"];

      hearts.assignAll(Map<String, int>.from(game["hearts"] ?? {}));
      usedWords.assignAll(List<String>.from(game["usedWords"] ?? []));
      sosUsed.assignAll(Map<String, bool>.from(game["sosUsed"] ?? {}));

      _syncConsent(game);

      if (nextStatus == WordChainStatus.inviting) {
        invitedAt.value = _parseTimestamp(game["invitedAt"]);
        _maybeStartCountdown();
      } else if (nextStatus == WordChainStatus.countdown) {
        _handleCountdown(game);
      } else {
        _countdownTimer?.cancel();
        _countdownStartedAt = null;
        _localCountdownStartedAt = null;
        countdownSeconds.value = _countdownTotalSeconds;
        _startingGame = false;
      }

      if (nextStatus == WordChainStatus.playing && turnUid.value == uid) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  // ================= TIMER =================
  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (turnUid.value != uid) return;

      remainingSeconds.value--;

      await service.updateTimer(roomId, remainingSeconds.value);

      if (remainingSeconds.value <= 0) {
        await _onTimeout();
      }
    });
  }

  // ================= TIMEOUT LOGIC =================
  Future<void> _onTimeout() async {
    HapticFeedback.heavyImpact();
    _timer?.cancel();

    await service.handleTimeout(
      roomId: roomId,
      uid: uid,
    );
  }

  // ================= SUBMIT WORD =================
  Future<void> submitWord(String input) async {
    if (status.value != WordChainStatus.playing) return;
    if (turnUid.value != uid) return;

    final ok = service.validateWord(
      input: input,
      prevWord: currentWord.value,
      usedWords: usedWords,
    );

    if (!ok) {
      HapticFeedback.mediumImpact();
      return;
    }

    await service.submitCorrectWord(roomId, uid, input);
  }

  // ================= SOS =================
  Future<void> useSOS() async {
    if (sosUsed[uid] == true) return;
    await service.useSOS(roomId, uid);
  }

  // ================= INVITE =================
  Future<void> invite() async {
    await service.invite(roomId);
  }

  Future<void> respond(bool accept) async {
    final action =
        accept ? WordChainSubmitAction.accept : WordChainSubmitAction.decline;

    if (submittingAction.value != null) return;
    submittingAction.value = action;

    await service.respond(
      roomId: roomId,
      uid: uid,
      accept: accept,
    );
  }

  // ================= HELPERS =================
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

  void _syncConsent(Map<String, dynamic> game) {
    final consent = Map<String, dynamic>.from(game["consent"] ?? {});
    final prevOtherAccepted = otherConsent.value;

    myConsent.value = consent[uid] == true;
    otherConsent.value = _otherUid != null ? consent[_otherUid!] == true : false;

    if (!prevOtherAccepted && otherConsent.value) {
      opponentJustAccepted.value = true;

      Future.delayed(const Duration(milliseconds: 600), () {
        opponentJustAccepted.value = false;
      });
    }
  }

  void _maybeStartCountdown() {
    if (_isHost != true) return;
    if (_startingCountdown) return;
    if (!myConsent.value || !otherConsent.value) return;

    _startingCountdown = true;
    service.startCountdown(roomId);
  }

  void _resetGameState() {
    status.value = WordChainStatus.idle;
    currentWord.value = "";
    turnUid.value = "";
    remainingSeconds.value = 15;
    countdownSeconds.value = _countdownTotalSeconds;
    winnerUid.value = null;
    hearts.clear();
    usedWords.clear();
    sosUsed.clear();
    myConsent.value = false;
    otherConsent.value = false;
    invitedAt.value = null;
    submittingAction.value = null;
    opponentJustAccepted.value = false;
    _startingCountdown = false;
    _startingGame = false;
    _timer?.cancel();
    _countdownTimer?.cancel();
    _countdownStartedAt = null;
    _localCountdownStartedAt = null;
  }

  WordChainStatus _parseStatus(dynamic raw) {
    if (raw is! String) return WordChainStatus.idle;
    return WordChainStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WordChainStatus.idle,
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }

  void _handleCountdown(Map<String, dynamic> game) {
    final startedAt = _parseTimestamp(game["countdownStartedAt"]);
    if (startedAt == null) {
      if (_countdownStartedAt == null) {
        _localCountdownStartedAt ??= DateTime.now();
        _countdownStartedAt = _localCountdownStartedAt;
        _startCountdownTimer(null);
      }
      return;
    }

    if (_countdownStartedAt != startedAt) {
      _countdownStartedAt = startedAt;
      _localCountdownStartedAt ??= DateTime.now();
      _startingGame = false;
      _startCountdownTimer(startedAt);
    } else {
      _syncCountdown(startedAt);
    }
  }

  void _startCountdownTimer(DateTime? startedAt) {
    _countdownTimer?.cancel();
    _syncCountdown(startedAt);
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _syncCountdown(startedAt);
    });
  }

  void _syncCountdown(DateTime? startedAt) {
    final now = DateTime.now();
    final localElapsedMs = _localCountdownStartedAt == null
        ? 0
        : now.difference(_localCountdownStartedAt!).inMilliseconds;
    var serverElapsedMs = 0;
    if (startedAt != null) {
      serverElapsedMs = now.difference(startedAt).inMilliseconds;
      if (serverElapsedMs < 0) {
        serverElapsedMs = 0;
      }
    }
    final elapsedMs = math.max(localElapsedMs, serverElapsedMs);
    final remainingMs = (_countdownTotalSeconds * 1000) - elapsedMs;
    final remaining = (remainingMs / 1000)
        .ceil()
        .clamp(0, _countdownTotalSeconds)
        .toInt();
    countdownSeconds.value = remaining;

    if (remaining <= 0) {
      _countdownTimer?.cancel();
      _startGameIfHost();
    }
  }

  void _startGameIfHost() {
    if (_isHost != true) return;
    if (_startingGame) return;
    if (status.value != WordChainStatus.countdown) return;

    _startingGame = true;
    service.startGame(roomId);
  }

  // ================= CLEANUP =================
  @override
  void onClose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
