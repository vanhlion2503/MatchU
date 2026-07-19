import 'package:get/get.dart';
import 'package:matchu_app/controllers/profile/profile_privacy_controller.dart';
import 'package:matchu_app/repositories/profile_privacy/profile_privacy_repository.dart';

class ProfilePrivacyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfilePrivacyRepository>(() => ProfilePrivacyRepository());
    Get.lazyPut<ProfilePrivacyController>(
      () => ProfilePrivacyController(
        repository: Get.find<ProfilePrivacyRepository>(),
      ),
    );
  }
}
