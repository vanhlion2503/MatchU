import 'package:get/get.dart';
import 'package:matchu_app/controllers/matching/video_matching_admission_controller.dart';
import 'package:matchu_app/repositories/matching/video_matching_admission_repository.dart';
import 'package:matchu_app/services/chat/video_matching_admission_service.dart';

class VideoMatchingAdmissionBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<VideoMatchingAdmissionRepository>()) {
      Get.lazyPut<VideoMatchingAdmissionRepository>(
        () => VideoMatchingAdmissionService(),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VideoMatchingAdmissionController>()) {
      Get.lazyPut<VideoMatchingAdmissionController>(
        () => VideoMatchingAdmissionController(
          repository: Get.find<VideoMatchingAdmissionRepository>(),
        ),
        fenix: true,
      );
    }
  }
}
