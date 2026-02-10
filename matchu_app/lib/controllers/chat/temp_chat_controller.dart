import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_controller.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/models/quick_message.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/models/word_chain.dart';
import 'package:matchu_app/services/chat/rating_service.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import 'package:matchu_app/views/matching/match_transition_view.dart';
import '../auth/auth_controller.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart'; 

enum QuickMessagePhase {
  intro,       // 👋 Xin chào
  iceBreaker,  // 💬 Câu hỏi
}

class TempChatController extends GetxController {
  final String roomId;
  TempChatController(this.roomId);

  final TempChatService service = TempChatService();
  final uid = Get.find<AuthController>().user!.uid;
  final _db = FirebaseFirestore.instance;

  final remainingSeconds = 420.obs;
  final userLiked = RxnBool();
  final otherLiked = RxnBool();
  final isTyping = false.obs;
  final otherTyping = false.obs; 
  final hasLeft = false.obs;
  final hasSent30sWarning = false.obs;
  final otherAvgRating = RxnDouble();
  final replyingMessage = Rxn<Map<String, dynamic>>();
  final scrollController = ScrollController();
  final highlightedMessageId = RxnString();
  final Map<String, GlobalKey> messageKeys = {};
  final showEmoji = false.obs;
  final inputController = TextEditingController();
  final otherRatingCount = RxnInt();
  final otherAnonymousAvatar = RxnString();
  final otherGender = RxnString();
  final _justSentMessage = false.obs;
  final showQuickMessages = true.obs;
  final quickPhase = QuickMessagePhase.intro.obs;
  
  bool _shownOtherLikeEffect = false;
  bool _isEnding = false;
  bool _roomStatusKnown = false;
  bool _roomIsActive = true;
  int _lastMessageCount = 0;
  int? _lastHapticSecond;
  bool _hasNavigatedToMatch = false;

  Timer? _typingTimer;
  Timer? _timer;
  StreamSubscription? _roomSub;
  StreamSubscription? _avatarSub;
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
    QuickMessage(id: "travel", text: "🌍 Nếu được đi du lịch, bạn muốn đi đâu?"),
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
    60,  // phút 1
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
    telepathy = Get.put(TelepathyController(roomId), tag: roomId);
    ever<TelepathyStatus>(telepathy.status, (status) {
      if (_telepathyAccepted) return;
      if (status == TelepathyStatus.countdown ||
          status == TelepathyStatus.playing ||
          status == TelepathyStatus.revealing ||
          status == TelepathyStatus.finished) {
        _telepathyAccepted = true;
      }
    });
    wordChain = Get.put(WordChainController(roomId), tag: roomId);
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
    });
    _setupWordChainInviteMoment();
    _startTimer();
    _listenRoom();
    _loadOtherUserRating();
    _saveMyAnonymousAvatarToRoom();
    _listenAnonymousAvatars();
    // Listen typing ?? auto scroll
    currentQuickMessages.assignAll(_introMessages);

    // Sau 20s ??i sang c?u h?i
    quickPhase.value = QuickMessagePhase.intro;
    currentQuickMessages.assignAll(_introMessages);
    ever<bool>(otherTyping, _onOtherTypingChanged);
  }

  List<QuickMessage> _pickRandomIceBreakers({int min = 6, int max = 7}) {
    final pool = List<QuickMessage>.from(_iceBreakerPool)..shuffle();

    final count = min + (DateTime.now().millisecondsSinceEpoch % (max - min + 1));
    return pool.take(count).toList();
  }


  void switchToIceBreaker() {
    if (quickPhase.value == QuickMessagePhase.iceBreaker) return;

    quickPhase.value = QuickMessagePhase.iceBreaker;

    // 🔥 RANDOM 6–7 CÂU CHO PHIÊN CHAT NÀY
    currentQuickMessages.assignAll(_pickRandomIceBreakers());
  }



  void _onOtherTypingChanged(bool isTyping) {
    if (!isTyping) return;
    if (!scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void toggleEmoji() {
    showEmoji.toggle();
  }

  void hideEmoji() {
    showEmoji.value = false;
  }

  void scrollToMessage(String messageId) {
    final key = messageKeys[messageId];
    if (key == null) return;

    final context = key.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );

    highlightedMessageId.value = messageId;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (highlightedMessageId.value == messageId) {
        highlightedMessageId.value = null;
      }
    });
  }


  void startReply(Map<String, dynamic> message) {
  replyingMessage.value = message;
  }

  void cancelReply() {
    replyingMessage.value = null;
  }


  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      remainingSeconds.value--;

      final sec = remainingSeconds.value;
      if (!_telepathyAccepted) {

      // 🔥 CHECK CÁC MỐC INVITE
      if (_telepathyInviteMoments.contains(sec) &&
          !_telepathyShownMoments.contains(sec)) {

        _telepathyShownMoments.add(sec);

        final room = await service.getRoom(roomId);
        final isA = room["userA"] == uid;
        if (!isA) return;

        final gameStatus = telepathy.status.value;
        if (gameStatus == TelepathyStatus.idle ||
            gameStatus == TelepathyStatus.cancelled ||
            gameStatus == TelepathyStatus.finished) {

          await telepathy.invite();
        }
      }
      }

      await _maybeAutoInviteWordChain(sec);

      if (_telepathyAccepted) return;

      if (sec <= 10 &&
          sec > 0 &&
          _lastHapticSecond != sec) {
        _lastHapticSecond = sec;
        HapticFeedback.lightImpact();
      }

      if (sec == 30 &&
        hasSent30sWarning.value == false) {

        hasSent30sWarning.value = true;

        final room = await service.getRoom(roomId);
        final isA = room["userA"] == uid;

        if (isA) {
          await service.sendSystemMessage(
            roomId: roomId,
            text: "⏰ Sắp hết giờ! Còn 30 giây",
            code: "timeout30",
            senderId: uid,
          );
        }
      }
      if (sec <= 0) {
        _timer?.cancel();
        endRoom("timeout");
      }
    });
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

    final room = await service.getRoom(roomId);
    final isA = room["userA"] == uid;
    if (!isA) return;

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

    _timer?.cancel();

    try {
      final room = await service.getRoom(roomId);

      // 🔒 GUARD SERVER STATE
      if (room["status"] != "active") return;

      await service.endRoom(
        roomId: roomId,
        uid: uid,
        reason: reason,
      );
    } catch (e) {
      _isEnding = false; // cho retry nếu lỗi network
      rethrow;
    }
  }


  void _listenRoom(){
    _roomSub = service.listenRoom(roomId).listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data() as Map<String,dynamic>;
      _roomStatusKnown = true;
      _roomIsActive = data["status"] == "active";
      final typing = data["typing"] ?? {};
      final isA = data["userA"] == uid;

      otherTyping.value = isA ? typing["userB"] == true : typing["userA"] == true;


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


      if (data["status"] == "ended") {

        if (_hasNavigatedToMatch) return;
        if (hasLeft.value == true) return;

        final matchController = Get.find<MatchingController>();
        matchController.isMatched.value = false;
        if (hasLeft.value == true) {
          return;
        }
        final myUid = uid;
        final toUid = myUid == data["userA"] ? data["userB"] : data["userA"];
        // 👉 Người ở lại
        Get.snackbar(
          "Thông báo",
          "Người kia đã rời phòng",
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

      if (data["userALiked"] == true && data["userBLiked"] == true && data["status"] == "active") {
        final matchController = Get.find<MatchingController>();
        matchController.isMatched.value = false;

        final myUid = uid;
        final userA = data["userA"];
        final userB = data["userB"];
        final toUid = myUid == userA ? userB : userA;
        
        await RatingService.autoRate(
          roomId: roomId,
          fromUid: myUid,
          toUid: toUid,
        );
        if (_hasNavigatedToMatch) return;
        _hasNavigatedToMatch = true;

        await _roomSub?.cancel();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.off(
            () => MatchTransitionView(
              tempRoomId: roomId, // 👈 CHỈ TRUYỀN TEMP ROOM
              myAvatar: Get.find<AnonymousAvatarController>()
                  .selectedAvatar.value!,
              otherAvatar: otherAnonymousAvatar.value!,
            ),
          );
        });
      }
    });
  }

  Future<void> send(String text, {String type = "text"}) async {

    switchToIceBreaker();

    if (!_canUseRoomActions) return;
    
    final reply = replyingMessage.value;

    _justSentMessage.value = true;

    try {
      await service.sendMessages(
        roomId,
        TempMessageModel(
          senderId: uid,
          text: text,
          type: type,
          replyToId: reply?["id"],
          replyText: reply?["text"],
        ),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _justSentMessage.value = false;
        Get.snackbar(
          "Thông báo",
          "Không thể gửi tin nhắn lúc này.",
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
        return;
      }
      _justSentMessage.value = false;
      rethrow;
    }

    // 🔥 clear reply SAU KHI GỬI
    replyingMessage.value = null;

    // 🔥 FIX CỐT LÕI: bật lại QuickMessageBar nếu input trống
    Future.microtask(() {
      if (inputController.text.trim().isEmpty) {
        showQuickMessages.value = true;
      }
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool get _canUseRoomActions {
    if (!_roomStatusKnown) return true;
    return _roomIsActive;
  }

  Future<bool> _isRoomActive() async {
    if (_roomStatusKnown) return _roomIsActive;
    final room = await service.getRoom(roomId);
    _roomStatusKnown = true;
    _roomIsActive = room["status"] == "active";
    return _roomIsActive;
  }

  /// Auto scroll khi có tin nhắn mới (giống long_chat)
  void onNewMessages(int newCount, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return;

    final hasNewMessage = newCount > _lastMessageCount;
    _lastMessageCount = newCount;

    if (!hasNewMessage) return;

    final newest = docs.last; // Vì orderBy createdAt, tin mới nhất ở cuối
    final isFromMe = newest["senderId"] == uid;

    if (_justSentMessage.value && isFromMe) {
      _justSentMessage.value = false;
      _scrollToBottom();
    } else if (!isFromMe) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }



  Future<void> like(bool value) async{
    if (userLiked.value != null) return;
    HapticFeedback.lightImpact();

    await service.setLike(
      roomId: roomId, 
      uid: uid, 
      value: value
    );
    userLiked.value = value;
  }

  Future<void> leaveByDislike() async {
    if (hasLeft.value) return; // 🔒 chặn double tap
    hasLeft.value = true;

    _timer?.cancel();

    final matchController = Get.find<MatchingController>();
    matchController.isMatched.value = false;
    // 🔹 Lấy snapshot room TRƯỚC khi end
    final room = await service.getRoom(roomId);
    final userA = room["userA"];
    final userB = room["userB"];
    final toUid = uid == userA ? userB : userA;

    // ❗ Chỉ set dislike nếu chưa like
    if (userLiked.value == null) {
      await service.setLike(
        roomId: roomId,
        uid: uid,
        value: false,
      );
      userLiked.value = false;
    }

    await service.endRoom(
      roomId: roomId,
      uid: uid,
      reason: "left",
    );
    Get.offAllNamed(
      "/rating",
      arguments: 
      {
        "roomId": roomId,
        "toUid": toUid,
        "anonymousAvatar": otherAnonymousAvatar.value,
      },
    );
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
      service.setTyping(
        roomId: roomId,
        uid: uid,
        typing: true,
      );
    }

    _typingTimer?.cancel();

    if (!hasText) {
      isTyping.value = false;
      service.setTyping(
        roomId: roomId,
        uid: uid,
        typing: false,
      );
      return;
    }

    _typingTimer = Timer(const Duration(seconds: 3), () {
      isTyping.value = false;
      service.setTyping(
        roomId: roomId,
        uid: uid,
        typing: false,
      );
    });
  }

  void stopTyping() {
    if (!isTyping.value) return;

    isTyping.value = false;
    _typingTimer?.cancel();

    service.setTyping(
      roomId: roomId,
      uid: uid,
      typing: false,
    );
  }

  // ================= REACTION =================
  void onReactMessage({
    required String messageId,
    required String reactionId,
  }) {
    if (!_canUseRoomActions) return;

    service.toggleReaction(
      roomId: roomId,
      messageId: messageId,
      uid: uid,
      reactionId: reactionId,
    );
  }

  Future<void> _loadOtherUserRating() async {
    final room = await service.getRoom(roomId);
    final isA = room["userA"] == uid;
    final otherUid = isA ? room["userB"] : room["userA"];

    final userSnap = await FirebaseFirestore.instance
      .collection("users")
      .doc(otherUid)
      .get();

    if (!userSnap.exists) return;
    final data = userSnap.data()!;


    otherAvgRating.value = (data["avgChatRating"] ?? 5.0).toDouble();

    otherRatingCount.value = (data["totalChatRatings"] ?? 0) as int;

    otherGender.value = data["gender"];


  }

  Future<void> _saveMyAnonymousAvatarToRoom() async {
    final anonAvatarC = Get.find<AnonymousAvatarController>();
    final myAvatar = anonAvatarC.selectedAvatar.value;

    if (myAvatar == null) return;

    await _db.collection("tempChats").doc(roomId).update({
      "anonymousAvatars.$uid": myAvatar,
    });
  }

  void _listenAnonymousAvatars() {
    _avatarSub = _db.collection("tempChats").doc(roomId).snapshots().listen((doc) {
      if (!doc.exists) return;

      final data = doc.data()!;
      final avatars =
          Map<String, dynamic>.from(data["anonymousAvatars"] ?? {});
      final participants = List<String>.from(data["participants"]);

      final otherUid = participants.firstWhere((e) => e != uid);
      otherAnonymousAvatar.value = avatars[otherUid];
    });
  }

  void cleanupMessageKeys(Set<String> aliveIds) {
    messageKeys.removeWhere((key, _) => !aliveIds.contains(key));
  }

  void markTelepathyAccepted() {
    _telepathyAccepted = true;
  }


  @override
  void onClose() {
    service.setTyping(
      roomId: roomId,
      uid: uid,
      typing: false,
    );
    _typingTimer?.cancel();
    _timer?.cancel();
    _roomSub?.cancel();
    _avatarSub?.cancel();
    inputController.dispose();
    super.onClose();
  }

}
