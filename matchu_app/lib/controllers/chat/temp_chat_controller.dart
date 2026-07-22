import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_controller.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/models/quick_message.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/models/word_chain.dart';
import 'package:matchu_app/services/chat/rating_service.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import 'package:matchu_app/repositories/chat/temp_chat_repository.dart';
import 'package:matchu_app/views/matching/match_transition_view.dart';
import 'package:matchu_app/translations/matching_chat_translations.dart';
import '../auth/auth_controller.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

enum QuickMessagePhase {
  intro, // 👋 Xin chào
  iceBreaker, // 💬 Câu hỏi
}

enum TempChatLifecycle { joining, active, ending, ended, converting, converted }

class TempChatController extends GetxController {
  final String roomId;
  TempChatController(
    this.roomId, {
    TempChatRepository? service,
    TelepathyController? telepathyController,
    WordChainController? wordChainController,
  }) : service = service ?? TempChatService(),
       _telepathyController = telepathyController,
       _wordChainController = wordChainController;

  final TempChatRepository service;
  final TelepathyController? _telepathyController;
  final WordChainController? _wordChainController;
  final uid = Get.find<AuthController>().user!.uid;
  final remainingSeconds = 420.obs;
  final lifecycle = TempChatLifecycle.joining.obs;
  final userLiked = RxnBool();
  final otherLiked = RxnBool();
  final isTyping = false.obs;
  final otherTyping = false.obs;
  final hasLeft = false.obs;
  final hasSent30sWarning = false.obs;
  final otherAvgRating = RxnDouble();
  final otherPeerSummary = Rxn<ChatPeerSummary>();
  final replyingMessage = Rxn<Map<String, dynamic>>();
  final scrollController = ScrollController();
  final Map<String, GlobalKey> messageKeys = {};
  final Map<String, RxBool> _messageHighlights = {};
  String? _highlightedMessageId;
  final newMessagesBelow = 0.obs;
  final showEmoji = false.obs;
  final inputController = TextEditingController();
  final otherRatingCount = RxnInt();
  final otherAnonymousAvatar = RxnString();
  final otherGender = RxnString();
  final otherIsFaceVerified = false.obs;
  final _justSentMessage = false.obs;
  final showQuickMessages = true.obs;
  final isSendingMessage = false.obs;
  final quickPhase = QuickMessagePhase.intro.obs;

  bool _shownOtherLikeEffect = false;
  bool _isEnding = false;
  bool _roomStatusKnown = false;
  bool _roomIsActive = true;
  bool? _isUserA;
  bool _processingTimerEvents = false;
  String? _lastMessageId;
  bool _isNearMessageBottom = true;
  int? _lastHapticSecond;
  int _lastTimerSecond = 421;
  bool _hasNavigatedToMatch = false;
  String? _otherUid;

  Timer? _typingTimer;
  Timer? _otherTypingExpiryTimer;
  Timer? _timer;
  StreamSubscription? _roomSub;
  StreamSubscription? _typingSub;
  final List<Worker> _workers = [];
  DateTime? _expiresAt;
  VoidCallback? onOtherLiked;
  final currentQuickMessages = <QuickMessage>[].obs;

  final _introMessages = [
    QuickMessage(id: "vanTay", text: "👋", type: "emoji"),
    QuickMessage(id: "wave", text: "👋 Xin chào!"),
    QuickMessage(id: "hello", text: "😊 Hello~"),
    QuickMessage(id: "nice", text: "✨ Rất vui được gặp bạn"),
  ];

  final _iceBreakerPool = <QuickMessage>[
    QuickMessage(id: "day", text: "💬 Hôm nay của bạn thế nào?"),
    QuickMessage(id: "music", text: "🎧 Bạn hay nghe nhạc gì?"),
    QuickMessage(id: "coffee", text: "☕ Cà phê hay trà?"),
    QuickMessage(
      id: "travel",
      text: "🌍 Nếu được đi du lịch, bạn muốn đi đâu?",
    ),
    QuickMessage(id: "food", text: "🍜 Món bạn thích nhất là gì?"),
    QuickMessage(id: "movie", text: "🎬 Bộ phim bạn xem gần đây nhất?"),
    QuickMessage(id: "pet", text: "🐶 Bạn thích chó hay mèo?"),
    QuickMessage(id: "hobby", text: "🎯 Lúc rảnh bạn hay làm gì?"),
    QuickMessage(id: "sleep", text: "🌙 Bạn là cú đêm hay dậy sớm?"),
    QuickMessage(id: "music2", text: "🎵 Bài hát bạn nghe nhiều nhất gần đây?"),
    QuickMessage(id: "sport", text: "⚽ Bạn có chơi thể thao không?"),
  ];

  // ⏱ Các mốc sẽ hiện invite (remainingSeconds)
  static const List<int> _telepathyInviteMoments = [
    400, // giây 20
    360, // phút 6
    300, // phút 5
    240, // phút 4
    180, // phút 3
    120, // phút 2
    60, // phút 1
  ];
  bool _telepathyAccepted = false;
  final Set<int> _telepathyShownMoments = {};

  static const int _wordChainInviteStartAt = 360;
  static const int _wordChainInviteEndAt = 120;

  final Random _wordChainRandom = Random();
  int? _wordChainInviteAt;
  bool _wordChainAutoInviteTriggered = false;
  bool _wordChainAutoInviteLocked = false;

  late final TelepathyController telepathy;
  late final WordChainController wordChain;

  @override
  void onInit() {
    super.onInit();
    telepathy =
        _telepathyController ?? Get.find<TelepathyController>(tag: roomId);
    _workers.add(
      ever<TelepathyStatus>(telepathy.status, (status) {
        if (_telepathyAccepted) return;
        if (status == TelepathyStatus.countdown ||
            status == TelepathyStatus.playing ||
            status == TelepathyStatus.revealing ||
            status == TelepathyStatus.finished) {
          _telepathyAccepted = true;
        }
      }),
    );
    wordChain =
        _wordChainController ?? Get.find<WordChainController>(tag: roomId);
    _workers.add(
      ever<WordChainStatus>(wordChain.status, (status) {
        if (status == WordChainStatus.inviting) {
          _wordChainAutoInviteTriggered = true;
        }
        if (status == WordChainStatus.countdown ||
            status == WordChainStatus.playing ||
            status == WordChainStatus.reward ||
            status == WordChainStatus.finished) {
          _wordChainAutoInviteLocked = true;
        }
      }),
    );
    _setupWordChainInviteMoment();
    _startTimer();
    _listenRoom();
    _listenTypingPresence();
    unawaited(_loadOtherUserRating().catchError((_) {}));
    // Listen typing ?? auto scroll
    currentQuickMessages.assignAll(_introMessages);

    // Sau 20s ??i sang c?u h?i
    quickPhase.value = QuickMessagePhase.intro;
    currentQuickMessages.assignAll(_introMessages);
    _workers.add(ever<bool>(otherTyping, _onOtherTypingChanged));
    scrollController.addListener(_onMessageScroll);
  }

  List<QuickMessage> _pickRandomIceBreakers({int min = 6, int max = 7}) {
    final pool = List<QuickMessage>.from(_iceBreakerPool)..shuffle();

    final count =
        min + (DateTime.now().millisecondsSinceEpoch % (max - min + 1));
    return pool.take(count).toList();
  }

  void switchToIceBreaker() {
    if (quickPhase.value == QuickMessagePhase.iceBreaker) return;

    quickPhase.value = QuickMessagePhase.iceBreaker;

    // 🔥 RANDOM 6–7 CÂU CHO PHIÊN CHAT NÀY
    currentQuickMessages.assignAll(_pickRandomIceBreakers());
  }

  void _onOtherTypingChanged(bool isTyping) {
    if (isTyping && _isNearMessageBottom) {
      _scrollToBottom(duration: const Duration(milliseconds: 180));
    }
  }

  void _onMessageScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    _isNearMessageBottom = position.maxScrollExtent - position.pixels <= 120;
    if (_isNearMessageBottom && newMessagesBelow.value != 0) {
      newMessagesBelow.value = 0;
    }
  }

  void toggleEmoji() {
    showEmoji.toggle();
  }

  void hideEmoji() {
    showEmoji.value = false;
  }

  void dismissComposerState({bool clearReply = false}) {
    stopTyping();
    hideEmoji();
    FocusManager.instance.primaryFocus?.unfocus();
    if (clearReply) {
      cancelReply();
    }
  }

  void scrollToMessage(String messageId) {
    final context = messageKeys[messageId]?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );

    final previous = _highlightedMessageId;
    if (previous != null && previous != messageId) {
      _messageHighlights[previous]?.value = false;
    }
    _highlightedMessageId = messageId;
    highlightFor(messageId).value = true;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (_highlightedMessageId == messageId) {
        highlightFor(messageId).value = false;
        _highlightedMessageId = null;
      }
    });
  }

  RxBool highlightFor(String messageId) {
    return _messageHighlights.putIfAbsent(messageId, () => false.obs);
  }

  void cleanupMessageState(Set<String> aliveIds) {
    _messageHighlights.removeWhere((id, _) => !aliveIds.contains(id));
    messageKeys.removeWhere((id, _) => !aliveIds.contains(id));
    if (_highlightedMessageId != null &&
        !aliveIds.contains(_highlightedMessageId)) {
      _highlightedMessageId = null;
    }
  }

  void startReply(Map<String, dynamic> message) {
    replyingMessage.value = message;
  }

  void cancelReply() {
    replyingMessage.value = null;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final expiresAt = _expiresAt;
      if (expiresAt == null) return;
      final remainingMs = expiresAt.difference(DateTime.now()).inMilliseconds;
      remainingSeconds.value =
          remainingMs <= 0 ? 0 : ((remainingMs + 999) ~/ 1000);

      final sec = remainingSeconds.value;
      if (sec <= 10 && sec > 0 && _lastHapticSecond != sec) {
        _lastHapticSecond = sec;
        HapticFeedback.lightImpact();
      }
      if (sec <= 0) {
        _timer?.cancel();
        unawaited(endRoom("timeout").catchError((_) {}));
        return;
      }

      // Serialize network work outside the periodic callback. Slow Firestore
      // calls can no longer overlap subsequent timer ticks.
      unawaited(_processTimerEvents(sec).catchError((_) {}));
    });
  }

  Future<void> _processTimerEvents(int sec) async {
    if (_processingTimerEvents || !_roomIsActive) return;
    _processingTimerEvents = true;
    try {
      if (!_telepathyAccepted) {
        final crossedMoments =
            _telepathyInviteMoments
                .where(
                  (moment) =>
                      sec <= moment &&
                      _lastTimerSecond > moment &&
                      !_telepathyShownMoments.contains(moment),
                )
                .toList();
        _lastTimerSecond = sec;
        if (crossedMoments.isNotEmpty) {
          _telepathyShownMoments.addAll(crossedMoments);
          if (_isUserA == true) {
            final gameStatus = telepathy.status.value;
            if (gameStatus == TelepathyStatus.idle ||
                gameStatus == TelepathyStatus.cancelled ||
                gameStatus == TelepathyStatus.finished) {
              await telepathy.invite();
            }
          }
        }
      }

      await _maybeAutoInviteWordChain(sec);

      if (sec <= 30 && sec > 0 && !hasSent30sWarning.value) {
        hasSent30sWarning.value = true;
        if (_isUserA == true) {
          await service.sendSystemMessage(
            roomId: roomId,
            text: "⏰ Sắp hết giờ! Còn 30 giây",
            code: "timeout30",
            senderId: uid,
          );
        }
      }
    } finally {
      _processingTimerEvents = false;
    }
  }

  void _setupWordChainInviteMoment() {
    if (_wordChainInviteAt != null) return;
    final range = _wordChainInviteStartAt - _wordChainInviteEndAt;
    if (range <= 0) {
      _wordChainInviteAt = _wordChainInviteStartAt;
      return;
    }
    _wordChainInviteAt =
        _wordChainInviteEndAt + _wordChainRandom.nextInt(range + 1);
  }

  bool get canInviteWordChain {
    final chainStatus = wordChain.status.value;
    if (chainStatus == WordChainStatus.inviting ||
        chainStatus == WordChainStatus.countdown ||
        chainStatus == WordChainStatus.playing ||
        chainStatus == WordChainStatus.reward) {
      return false;
    }

    final tp = telepathy.status.value;
    if (tp == TelepathyStatus.inviting ||
        tp == TelepathyStatus.countdown ||
        tp == TelepathyStatus.playing ||
        tp == TelepathyStatus.revealing) {
      return false;
    }

    return true;
  }

  Future<void> _maybeAutoInviteWordChain(int sec) async {
    if (_wordChainAutoInviteLocked || _wordChainAutoInviteTriggered) return;
    if (_wordChainInviteAt == null) return;
    if (sec > _wordChainInviteStartAt) return;
    if (sec > _wordChainInviteAt!) return;
    if (!canInviteWordChain) return;
    if (!await _isRoomActive()) return;

    if (_isUserA != true) return;

    _wordChainAutoInviteTriggered = true;
    await wordChain.invite();
  }

  Future<void> inviteWordChainManual() async {
    if (!await _isRoomActive()) return;
    if (!canInviteWordChain) return;
    _wordChainAutoInviteTriggered = true;
    await wordChain.invite();
  }

  Future<void> endRoom(String reason) async {
    if (_isEnding) return;
    _isEnding = true;
    lifecycle.value = TempChatLifecycle.ending;

    _timer?.cancel();

    try {
      final room = await service.getRoom(roomId);

      // 🔒 GUARD SERVER STATE
      if (room["status"] != "active") return;

      await service.endRoom(roomId: roomId, uid: uid, reason: reason);
    } catch (e) {
      _isEnding = false; // cho retry nếu lỗi network
      lifecycle.value = TempChatLifecycle.active;
      rethrow;
    }
  }

  void _listenRoom() {
    _roomSub = service.listenRoom(roomId).listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      // The parent owns the only room listener. Game controllers consume only
      // their state slices, avoiding duplicate Firestore subscriptions.
      telepathy.syncRoomState(data);
      wordChain.syncRoomState(data);
      _syncServerExpiry(data);
      _roomStatusKnown = true;
      _roomIsActive = data["status"] == "active";
      lifecycle.value = switch (data["status"]?.toString()) {
        "ended" => TempChatLifecycle.ended,
        "converted" => TempChatLifecycle.converted,
        _ => TempChatLifecycle.active,
      };
      final typing = data["typing"] ?? {};
      final isA = data["userA"] == uid;
      _isUserA = isA;

      final avatars = Map<String, dynamic>.from(
        data["anonymousAvatars"] ?? const {},
      );
      final otherUid = isA ? data["userB"] : data["userA"];
      if (otherUid is String) {
        _otherUid = otherUid;
      }
      otherAnonymousAvatar.value = avatars[otherUid]?.toString();

      if (!_hasPeerPresence) {
        otherTyping.value =
            isA ? typing["userB"] == true : typing["userA"] == true;
      }

      userLiked.value = isA ? data["userALiked"] : data["userBLiked"];
      final newOtherLiked = isA ? data["userBLiked"] : data["userALiked"];

      if (newOtherLiked == true &&
          otherLiked.value != true &&
          !_shownOtherLikeEffect) {
        _shownOtherLikeEffect = true;

        // 🔔 THÔNG BÁO UI
        onOtherLiked?.call();
      }

      otherLiked.value = newOtherLiked;

      if (data["status"] == "converted" && data["permanentRoomId"] is String) {
        if (_hasNavigatedToMatch) return;
        _hasNavigatedToMatch = true;
        await _roomSub?.cancel();
        if (Get.isRegistered<MatchingController>()) {
          Get.find<MatchingController>().isMatched.value = false;
        }
        Get.offNamed(
          "/chat",
          arguments: {"roomId": data["permanentRoomId"] as String},
        );
        return;
      }

      if (data["status"] == "ended") {
        if (_hasNavigatedToMatch) return;
        if (hasLeft.value == true) return;
        _hasNavigatedToMatch = true;
        await _roomSub?.cancel();

        if (Get.isRegistered<MatchingController>()) {
          Get.find<MatchingController>().isMatched.value = false;
        }
        if (hasLeft.value == true) {
          return;
        }
        final myUid = uid;
        final toUid = myUid == data["userA"] ? data["userB"] : data["userA"];
        // 👉 Người ở lại
        final endedBy = data["endedBy"]?.toString();
        final endedReason = data["endedReason"]?.toString();
        final notice =
            endedReason == "timeout" || endedBy == "system"
                ? "Cuộc trò chuyện đã kết thúc"
                : "Người kia đã rời phòng";
        Get.snackbar(
          MatchingChatTranslationKeys.notice.tr,
          matchingChatTr(notice),
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (isClosed) return;
          Get.offAllNamed(
            "/rating",
            arguments: {
              "roomId": roomId,
              "toUid": toUid,
              "anonymousAvatar": otherAnonymousAvatar.value,
            },
          );
        });
      }

      if (data["userALiked"] == true &&
          data["userBLiked"] == true &&
          data["status"] == "active") {
        lifecycle.value = TempChatLifecycle.converting;
        if (_hasNavigatedToMatch) return;
        _hasNavigatedToMatch = true;
        await _roomSub?.cancel();

        if (Get.isRegistered<MatchingController>()) {
          Get.find<MatchingController>().isMatched.value = false;
        }

        final myUid = uid;
        final userA = data["userA"];
        final userB = data["userB"];
        final toUid = myUid == userA ? userB : userA;

        try {
          await RatingService.autoRate(
            roomId: roomId,
            fromUid: myUid,
            toUid: toUid,
          );
        } catch (_) {
          // Rating must not block a successful mutual match transition.
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.off(
            () => MatchTransitionView(
              tempRoomId: roomId, // 👈 CHỈ TRUYỀN TEMP ROOM
              myAvatar:
                  Get.find<AnonymousAvatarController>().selectedAvatar.value ??
                  'avt_01',
              otherAvatar: otherAnonymousAvatar.value ?? 'avt_01',
            ),
          );
        });
      }
    });
  }

  bool _hasPeerPresence = false;

  void _listenTypingPresence() {
    _typingSub = service.listenTyping(roomId).listen((snapshot) {
      QueryDocumentSnapshot<Map<String, dynamic>>? peer;
      for (final doc in snapshot.docs) {
        if (doc.id != uid) {
          peer = doc;
          break;
        }
      }
      if (peer == null) return; // Keep the legacy room.typing fallback.

      _hasPeerPresence = true;
      _otherTypingExpiryTimer?.cancel();
      final data = peer.data();
      final rawExpiry = data['expiresAt'];
      final expiry = rawExpiry is Timestamp ? rawExpiry.toDate() : null;
      final active =
          data['isTyping'] == true &&
          expiry != null &&
          expiry.isAfter(DateTime.now());
      otherTyping.value = active;

      if (active) {
        _otherTypingExpiryTimer = Timer(
          expiry.difference(DateTime.now()),
          () => otherTyping.value = false,
        );
      }
    });
  }

  Future<bool> send(String text, {String type = "text"}) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || normalizedText.length > 1000) return false;
    if (isSendingMessage.value || !_canUseRoomActions) return false;

    isSendingMessage.value = true;
    switchToIceBreaker();

    final reply = replyingMessage.value;

    _justSentMessage.value = true;

    try {
      await service.sendMessages(
        roomId,
        TempMessageModel(
          senderId: uid,
          text: normalizedText,
          type: type,
          replyToId: reply?["id"],
          replyText: reply?["text"],
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Temp chat send failed for room $roomId (${e.code}): ${e.message}',
      );
      if (e.code == 'permission-denied') {
        _justSentMessage.value = false;
        Get.snackbar(
          MatchingChatTranslationKeys.notice.tr,
          matchingChatTr("Không thể gửi tin nhắn lúc này."),
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
        return false;
      }
      _justSentMessage.value = false;
      Get.snackbar(
        MatchingChatTranslationKeys.notice.tr,
        matchingChatTr("Không thể gửi tin nhắn lúc này."),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint('Temp chat send failed for room $roomId: $error');
      debugPrintStack(stackTrace: stackTrace);
      _justSentMessage.value = false;
      Get.snackbar(
        MatchingChatTranslationKeys.notice.tr,
        matchingChatTr("Không thể gửi tin nhắn lúc này."),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      return false;
    } finally {
      isSendingMessage.value = false;
    }

    // 🔥 clear reply SAU KHI GỬI
    replyingMessage.value = null;

    // 🔥 FIX CỐT LÕI: bật lại QuickMessageBar nếu input trống
    Future.microtask(() {
      if (inputController.text.trim().isEmpty) {
        showQuickMessages.value = true;
      }
    });
    return true;
  }

  bool get _canUseRoomActions {
    return lifecycle.value == TempChatLifecycle.joining ||
        lifecycle.value == TempChatLifecycle.active;
  }

  Future<bool> _isRoomActive() async {
    if (_roomStatusKnown) return _roomIsActive;
    final room = await service.getRoom(roomId);
    _roomStatusKnown = true;
    _roomIsActive = room["status"] == "active";
    return _roomIsActive;
  }

  /// Auto scroll khi có tin nhắn mới (giống long_chat)
  void onNewMessages(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return;

    final newest = docs.last; // Vì orderBy createdAt, tin mới nhất ở cuối
    final previousMessageId = _lastMessageId;
    if (newest.id == previousMessageId) return;
    _lastMessageId = newest.id;
    final isFromMe = newest["senderId"] == uid;

    if (previousMessageId == null || isFromMe || _isNearMessageBottom) {
      _justSentMessage.value = false;
      _scrollToBottom();
    } else {
      newMessagesBelow.value++;
    }
  }

  void _scrollToBottom({
    Duration duration = const Duration(milliseconds: 260),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      newMessagesBelow.value = 0;
    });
  }

  void scrollToLatestMessages() => _scrollToBottom();

  Future<void> like(bool value) async {
    if (userLiked.value != null) return;
    HapticFeedback.lightImpact();

    await service.setLike(roomId: roomId, uid: uid, value: value);
    userLiked.value = value;
  }

  Future<void> leaveByDislike() async {
    if (hasLeft.value) return;
    hasLeft.value = true;
    lifecycle.value = TempChatLifecycle.ending;
    _timer?.cancel();

    if (Get.isRegistered<MatchingController>()) {
      Get.find<MatchingController>().isMatched.value = false;
    }
    _hasNavigatedToMatch = true;

    // Do not make navigation depend on a Firestore transaction. In particular,
    // Telepathy may still be finishing and writing to the same room document.
    // The server update continues in the background while this route closes.
    unawaited(_finishLeaveOnServer());

    final toUid = _otherUid ?? await _resolveOtherUidForExit();
    if (toUid == null) {
      debugPrint('Temp chat exit could not resolve the peer for room $roomId');
      Get.offAllNamed('/main');
      return;
    }

    Get.offAllNamed(
      "/rating",
      arguments: {
        "roomId": roomId,
        "toUid": toUid,
        "anonymousAvatar": otherAnonymousAvatar.value,
      },
    );
  }

  Future<void> _finishLeaveOnServer() async {
    try {
      await service.endRoom(roomId: roomId, uid: uid, reason: "left");
    } catch (error, stackTrace) {
      // Exiting the local route must remain possible when the device is
      // temporarily offline. Firestore/server cleanup can recover separately.
      debugPrint('Temp chat leave sync failed for room $roomId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> _resolveOtherUidForExit() async {
    try {
      final room = await service
          .getRoom(roomId)
          .timeout(const Duration(seconds: 2));
      final userA = room["userA"];
      final userB = room["userB"];
      final otherUid = uid == userA ? userB : userA;
      return otherUid is String ? otherUid : null;
    } catch (error) {
      debugPrint(
        'Temp chat peer lookup failed during exit for room $roomId: $error',
      );
      return null;
    }
  }

  void onTypingChanged(String text) {
    if (!_canUseRoomActions) {
      if (isTyping.value) {
        stopTyping();
      }
      return;
    }
    final hasText = text.trim().isNotEmpty;

    if (hasText) {
      showQuickMessages.value = false;
    } else {
      // Chỉ hiện nếu đã ở iceBreaker hoặc intro
      showQuickMessages.value = true;
    }

    if (hasText && !isTyping.value) {
      isTyping.value = true;
      _setTypingSafely(true);
    }

    _typingTimer?.cancel();

    if (!hasText) {
      isTyping.value = false;
      _setTypingSafely(false);
      return;
    }

    _typingTimer = Timer(const Duration(seconds: 3), () {
      isTyping.value = false;
      _setTypingSafely(false);
    });
  }

  void stopTyping() {
    if (!isTyping.value) return;

    isTyping.value = false;
    _typingTimer?.cancel();

    _setTypingSafely(false);
  }

  // ================= REACTION =================
  void onReactMessage({required String messageId, required String reactionId}) {
    if (!_canUseRoomActions) return;

    unawaited(
      service
          .toggleReaction(
            roomId: roomId,
            messageId: messageId,
            uid: uid,
            reactionId: reactionId,
          )
          .catchError((_) {}),
    );
  }

  void _setTypingSafely(bool typing) {
    unawaited(
      service
          .setTyping(roomId: roomId, uid: uid, typing: typing)
          .catchError((_) {}),
    );
  }

  Future<void> _loadOtherUserRating() async {
    final room = await service.getRoom(roomId);
    final isA = room["userA"] == uid;
    final otherUid = (isA ? room["userB"] : room["userA"])?.toString();
    if (otherUid == null || otherUid.isEmpty) return;

    final summary = await service.getPeerSummary(otherUid);
    if (summary == null) return;

    otherPeerSummary.value = summary;
    // Do not present an artificial 5.0 score when the user has no ratings.
    otherAvgRating.value = summary.hasRatings ? summary.averageRating : null;
    otherRatingCount.value = summary.totalRatings;
    otherGender.value = summary.gender;
    otherIsFaceVerified.value = summary.isFaceVerified;
  }

  void _syncServerExpiry(Map<String, dynamic> room) {
    final expiresAt = room['expiresAt'];
    if (expiresAt is Timestamp) {
      _expiresAt = expiresAt.toDate();
      return;
    }

    // Compatibility for rooms created before expiresAt was introduced.
    final createdAt = room['createdAt'];
    if (createdAt is Timestamp) {
      _expiresAt = createdAt.toDate().add(const Duration(minutes: 7));
    }
  }

  void markTelepathyAccepted() {
    _telepathyAccepted = true;
  }

  @override
  void onClose() {
    _setTypingSafely(false);
    _typingTimer?.cancel();
    _otherTypingExpiryTimer?.cancel();
    _timer?.cancel();
    _roomSub?.cancel();
    _typingSub?.cancel();
    for (final worker in _workers) {
      worker.dispose();
    }
    scrollController.removeListener(_onMessageScroll);
    scrollController.dispose();
    inputController.dispose();
    super.onClose();
  }
}
