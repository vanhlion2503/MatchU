import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/chat_rating_model.dart';
import 'package:matchu_app/services/chat/rating_service.dart';

class RatingController extends GetxController{
  late final String roomId;
  late final String myUid;
  late final String toUid;

  final RxnString otherAnonymousAvatar = RxnString();
  final RxnString otherGender = RxnString();

  final rating = 5.0.obs;
  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments as Map<String, dynamic>;

    roomId = args["roomId"];
    toUid = args["toUid"];
    myUid = Get.find<AuthController>().user!.uid;

    otherAnonymousAvatar.value = args["anonymousAvatar"];
    otherGender.value = args["gender"];
  }

  
  Future<void> submit() async {
    if (isSubmitting.value) return; // 🔒 chặn double tap
    isSubmitting.value = true;

    try {
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

      Get.offAllNamed("/main");
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> skip() async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;

    try {
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

      Get.offAllNamed("/main");
    } finally {
      isSubmitting.value = false;
    }
  }
}