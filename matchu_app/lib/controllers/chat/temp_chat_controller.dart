import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';
import 'package:matchu_app/services/chat/temp_chat_service.dart';
import '../auth/auth_controller.dart';
import 'dart:async';

class TempChatController extends GetxController {
  final String roomId;
  TempChatController(this.roomId);

  final TempChatService service = TempChatService();
  final uid = Get.find<AuthController>().user!.uid;

  final remainingSeconds = 180.obs;
  final userLiked = RxnBool();
  final otherLiked = RxnBool();
  final isTyping = false.obs;

  Timer? _timer;
  StreamSubscription? _roomSub;

  @override
  void onInit() {
    super.onInit();
    _startTimer();
    _listenRoom();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remainingSeconds.value--;
      if (remainingSeconds.value <= 0) {
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

      final isA = data["userA"] == uid;

      userLiked.value = isA ? data["userALiked"] : data["userBLiked"];
      otherLiked.value = isA ? data["userBLiked"] : data["userALiked"];

      if (data["userALiked"] == false || data["userBLiked"] == false) {
        await endRoom("dislike");
      }

      if (data["userALiked"] == true && data["userBLiked"] == true && data["status"] == "active") {
        final newRoomId = await service.convertToPermanent(roomId);
        Get.offNamed("/chat", arguments: {"roomId": newRoomId});
      }
    });
  }

  Future<void> send(String text)async{
    await service.sendMessages(
      roomId, 
      TempMessageModel(
        senderId: uid, 
        text: text, 
        )
      );
  }

  Future<void> like(bool value) async{
    await service.setLike(
      roomId: roomId, 
      uid: uid, 
      value: value);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _roomSub?.cancel();
    super.onClose();
  }

  Future<void> leaveRoom({String reason = "manual"}) async {
    _timer?.cancel();

    final room = await service.getRoom(roomId);

    // 🔥 Nếu room đã ended → CHỈ RỜI UI
    if (room["status"] != "active") {
      Get.offNamed("/rating", arguments: {"roomId": roomId});
      return;
    }

    // 🔥 Chỉ user đầu tiên mới ghi Firestore
    await service.endRoom(
      roomId: roomId,
      uid: uid,
      reason: reason,
    );

    Get.offNamed("/rating", arguments: {"roomId": roomId});
  }

}
