import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/services/chat/rating_service.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import '../auth/auth_controller.dart';
import 'dart:async';
import 'package:flutter/services.dart'; 

class TempChatController extends GetxController {
  final String roomId;
  TempChatController(this.roomId);

  final TempChatService service = TempChatService();
  final uid = Get.find<AuthController>().user!.uid;

  final remainingSeconds = 180.obs;
  final userLiked = RxnBool();
  final otherLiked = RxnBool();
  final isTyping = false.obs;
  final otherTyping = false.obs; 
  final hasLeft = false.obs;
  final hasSent30sWarning = false.obs;
  final otherAvgRating = RxnDouble();
  final replyingMessage = Rxn<Map<String, dynamic>>();


  Timer? _typingTimer;
  Timer? _timer;
  StreamSubscription? _roomSub;

  @override
  void onInit() {
    super.onInit();
    _startTimer();
    _listenRoom();
    _loadOtherUserRating();
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
          Get.offNamed(
            "/rating",
            arguments: {
              "roomId": roomId,
              "toUid": toUid,
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

        final newRoomId = await service.convertToPermanent(roomId);
        Get.offNamed("/chat", arguments: {"roomId": newRoomId});
      }
    });
  }

  Future<void> send(String text) async {
    final reply = replyingMessage.value;

    await service.sendMessages(
      roomId,
      TempMessageModel(
        senderId: uid,
        text: text,
        replyToId: reply?["id"],
        replyText: reply?["text"],
      ),
    );

    // 🔥 clear reply SAU KHI GỬI
    replyingMessage.value = null;
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
      arguments: {
        "roomId": roomId,
        "toUid": toUid,
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

    _typingTimer = Timer(const Duration(seconds: 5), () {
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

  Future<void> _loadOtherUserRating() async {
    final room = await service.getRoom(roomId);
    final isA = room["userA"] == uid;
    final otherUid = isA ? room["userB"] : room["userA"];

    final userSnap = await FirebaseFirestore.instance
      .collection("users")
      .doc(otherUid)
      .get();

    if (!userSnap.exists) return;

    otherAvgRating.value = (userSnap.data()?["avgChatRating"] ?? 5.0).toDouble();

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
    super.onClose();
  }

  


}
