import 'dart:async';
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
  String? _otherUid;
  bool? _isHost;
  bool _startingGame = false;

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
        _startingGame = false;
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
        _maybeStartGame();
      }

      if (nextStatus == WordChainStatus.playing &&
          turnUid.value == uid) {
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

    // 💥 Mất tim
    await service.loseHeartOnly(roomId, uid);

    // ⏱ Reset timer — KHÔNG đổi lượt
    await service.resetTimer(roomId);
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
      // ❌ Nhập sai → KHÔNG mất tim
      HapticFeedback.mediumImpact();
      return;
    }

    // ✅ Đúng → đổi lượt
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

  void _maybeStartGame() {
    if (_isHost != true) return;
    if (_startingGame) return;
    if (!myConsent.value || !otherConsent.value) return;

    _startingGame = true;
    service.startGame(roomId);
  }

  void _resetGameState() {
    status.value = WordChainStatus.idle;
    currentWord.value = "";
    turnUid.value = "";
    remainingSeconds.value = 15;
    winnerUid.value = null;
    hearts.clear();
    usedWords.clear();
    sosUsed.clear();
    myConsent.value = false;
    otherConsent.value = false;
    invitedAt.value = null;
    submittingAction.value = null;
    opponentJustAccepted.value = false;
    _startingGame = false;
    _timer?.cancel();
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

  // ================= CLEANUP =================
  @override
  void onClose() {
    _timer?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
