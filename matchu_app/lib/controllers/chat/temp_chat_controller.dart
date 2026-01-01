import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/services/chat/rating_service.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import 'package:matchu_app/views/matching/match_transition_view.dart';
import '../auth/auth_controller.dart';
import 'dart:async';
import 'package:flutter/services.dart'; 

class TempChatController extends GetxController {
  final String roomId;
  TempChatController(this.roomId);

  final TempChatService service = TempChatService();
  final uid = Get.find<AuthController>().user!.uid;
  final _db = FirebaseFirestore.instance;

  final remainingSeconds = 180.obs;
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
  int _lastMessageCount = 0;
  bool _hasNavigatedToMatch = false;


  Timer? _typingTimer;
  Timer? _timer;
  StreamSubscription? _roomSub;
  StreamSubscription? _avatarSub;

  @override
  void onInit() {
    super.onInit();
    _startTimer();
    _listenRoom();
    _loadOtherUserRating();
    _saveMyAnonymousAvatarToRoom();
    _listenAnonymousAvatars();
    // Listen typing để auto scroll
    ever<bool>(otherTyping, _onOtherTypingChanged);
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
      if (remainingSeconds.value == 30 &&
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
      if (remainingSeconds.value <= 0) {
        _timer?.cancel();
        endRoom("timeout");
      }
    });
  }

  Future<void> endRoom(String reason) async {
    _timer?.cancel();
    await service.endRoom(
      roomId: roomId, 
      uid: uid, 
      reason: reason
      );
  }

  void _listenRoom(){
    _roomSub = service.listenRoom(roomId).listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data() as Map<String,dynamic>;
      final typing = data["typing"] ?? {};
      final isA = data["userA"] == uid;

      otherTyping.value = isA ? typing["userB"] == true : typing["userA"] == true;


      userLiked.value = isA ? data["userALiked"] : data["userBLiked"];
      otherLiked.value = isA ? data["userBLiked"] : data["userALiked"];

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
          Get.offNamed(
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
    final reply = replyingMessage.value;

    _justSentMessage.value = true;

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

    // 🔥 clear reply SAU KHI GỬI
    replyingMessage.value = null;

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
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
    final hasText = text.trim().isNotEmpty;

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

      final otherAvatarKey = avatars[otherUid];

      otherAnonymousAvatar.value = avatars[otherUid];
    });
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
