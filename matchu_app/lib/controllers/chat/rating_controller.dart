import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/chat_rating_model.dart';
import 'package:matchu_app/services/chat/rating_service.dart';

class RatingController extends GetxController{
  late final String roomId;
  late final String myUid;
  late final String toUid;

  final rating = 5.0.obs;

  void onInit() {
    super.onInit();
    final args = Get.arguments;
    roomId = args["roomId"];
    toUid = args["toUid"];
    myUid = Get.find<AuthController>().user!.uid;
  }

  Future<void> submit() async {
    await RatingService.submitRating(
      ChatRatingModel(
        roomId: roomId,
        fromUid: myUid,
        toUid: toUid,
        score: rating.value,
        skipped: false,
        createdAt: DateTime.now(),
      ),
    );

    Get.offAllNamed("/home");
  }

  Future<void> skip() async {
    await RatingService.submitRating(
      ChatRatingModel(
        roomId: roomId,
        fromUid: myUid,
        toUid: toUid,
        score: 0,
        skipped: true,
        createdAt: DateTime.now(),
      ),
    );

    Get.offAllNamed("/home");
  }
}