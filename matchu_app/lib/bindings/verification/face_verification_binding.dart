import 'package:get/get.dart';
import 'package:matchu_app/controllers/verification/face_verification_controller.dart';

class FaceVerificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FaceVerificationController>(() => FaceVerificationController());
  }
}
