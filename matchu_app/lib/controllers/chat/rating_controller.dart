import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/chat_rating_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/chat/rating_service.dart';
import 'package:matchu_app/services/user/user_service.dart';

class RatingController extends GetxController {
  final UserService _userService = UserService();

  late final String roomId;
  late final String myUid;
  late final String toUid;
  late final bool isVideoCall;
  String? _nextRoute;
  Map<String, dynamic>? _nextRouteArguments;

  final RxnString otherAnonymousAvatar = RxnString();
  final RxnString otherGender = RxnString();
  final otherIsFaceVerified = false.obs;

  final rating = 5.0.obs;
  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();

    final args = Map<String, dynamic>.from(Get.arguments as Map);

    roomId = args["roomId"];
    toUid = args["toUid"];
    myUid = Get.find<AuthController>().user!.uid;
    isVideoCall = args['experience'] == 'video';
    _nextRoute = args['nextRoute']?.toString();
    final nextArguments = args['nextRouteArguments'];
    if (nextArguments is Map) {
      _nextRouteArguments = Map<String, dynamic>.from(nextArguments);
    }

    otherAnonymousAvatar.value = args["anonymousAvatar"];
    otherGender.value = args["gender"];
    _loadOtherUserVerification();
  }

  Future<void> _loadOtherUserVerification() async {
    final user = await _userService.getUser(toUid);
    if (user == null) return;
    otherIsFaceVerified.value = user.isFaceVerified;
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

      _finishRating();
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

      _finishRating();
    } finally {
      isSubmitting.value = false;
    }
  }

  void _finishRating() {
    final nextRoute = _nextRoute;
    if (nextRoute != null && nextRoute.isNotEmpty) {
      Get.offAllNamed(nextRoute, arguments: _nextRouteArguments);
      return;
    }
    Get.offAllNamed(AppRouter.main);
  }
}
