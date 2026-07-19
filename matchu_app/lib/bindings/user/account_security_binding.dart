import 'package:get/get.dart';
import 'package:matchu_app/controllers/user/account_security_controller.dart';
import 'package:matchu_app/repositories/account_security/account_security_repository.dart';

class AccountSecurityBinding extends Bindings {
  @override
  void dependencies() {
    // Các route con dùng lại dependency của trang tổng quan nếu đang tồn tại,
    // đồng thời vẫn hoạt động độc lập khi mở bằng deep link.
    if (!Get.isRegistered<AccountSecurityRepository>()) {
      Get.lazyPut<AccountSecurityRepository>(() => AccountSecurityRepository());
    }
    if (!Get.isRegistered<AccountSecurityController>()) {
      Get.lazyPut<AccountSecurityController>(
        () => AccountSecurityController(
          repository: Get.find<AccountSecurityRepository>(),
        ),
      );
    }
  }
}
