import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_controller.dart';

class TempChatController extends GetxController {
  final String roomId;
  TempChatController(this.roomId);

  final _firestore = FirebaseFirestore.instance;
  final isLeaving = false.obs;

  Future<void> leaveRoom() async {
    if (isLeaving.value) return;
    isLeaving.value = true;

    final uid = Get.find<AuthController>().user!.uid;

    await _firestore.collection("tempChats").doc(roomId).update({
      "status": "ended",
      "endedBy": uid,
      "endedAt": FieldValue.serverTimestamp(),
    });

    Get.back(); // quay về matching / main
  }
}
