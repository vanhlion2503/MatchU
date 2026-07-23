import 'package:get/get.dart';
import 'package:matchu_app/controllers/verification/face_verification_controller.dart';
import 'package:matchu_app/services/verification/face_verification_service.dart';

class FaceVerificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FaceVerificationRepository>(() => FaceVerificationService());
    Get.lazyPut<FaceVerificationController>(
      () => FaceVerificationController(
        verificationRepository: Get.find<FaceVerificationRepository>(),
      ),
    );
  }
}
