import 'package:get/get.dart';
import 'package:matchu_app/controllers/security/chat_passcode_security_controller.dart';
import 'package:matchu_app/repositories/account_security/account_security_repository.dart';
import 'package:matchu_app/repositories/security/chat_passcode_security_repository.dart';

class ChatPasscodeSecurityBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AccountSecurityRepository>()) {
      Get.lazyPut<AccountSecurityRepository>(() => AccountSecurityRepository());
    }
    if (!Get.isRegistered<ChatPasscodeSecurityRepository>()) {
      Get.lazyPut<ChatPasscodeSecurityRepository>(
        () => ChatPasscodeSecurityRepository(
          accountSecurityRepository: Get.find<AccountSecurityRepository>(),
        ),
      );
    }
    if (!Get.isRegistered<ChatPasscodeSecurityController>()) {
      Get.lazyPut<ChatPasscodeSecurityController>(
        () => ChatPasscodeSecurityController(
          repository: Get.find<ChatPasscodeSecurityRepository>(),
        ),
      );
    }
  }
}
