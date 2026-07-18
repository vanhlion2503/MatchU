import 'package:get/get.dart';
import 'package:matchu_app/controllers/user/account_security_controller.dart';
import 'package:matchu_app/repositories/account_security/account_security_repository.dart';

class AccountSecurityBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountSecurityRepository>(() => AccountSecurityRepository());
    Get.lazyPut<AccountSecurityController>(
      () => AccountSecurityController(
        repository: Get.find<AccountSecurityRepository>(),
      ),
    );
  }
}
