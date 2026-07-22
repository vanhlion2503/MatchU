import 'package:get/get.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/repositories/matching/video_matching_repository.dart';
import 'package:matchu_app/services/chat/video_matching_service.dart';

class VideoMatchingBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    if (arguments is! Map ||
        arguments['targetGender'] is! String ||
        arguments['anonymousAvatar'] is! String) {
      throw ArgumentError(
        'Video matching requires targetGender and anonymousAvatar.',
      );
    }

    // A minimized matching session outlives its route. Reopening the route must
    // reuse the same controller instead of creating a second queue session.
    if (Get.isRegistered<VideoMatchingController>()) return;

    if (!Get.isRegistered<VideoMatchingRepository>()) {
      Get.lazyPut<VideoMatchingRepository>(() => VideoMatchingService());
    }
    Get.put<VideoMatchingController>(
      VideoMatchingController(
        targetGender: arguments['targetGender'] as String,
        anonymousAvatar: arguments['anonymousAvatar'] as String,
        repository: Get.find<VideoMatchingRepository>(),
      ),
      permanent: true,
    );
  }
}
