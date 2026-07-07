import 'package:get/get.dart';
import 'package:matchu_app/controllers/notification/notification_inbox_controller.dart';

class NotificationInboxBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationInboxController>(
      () => NotificationInboxController(),
    );
  }
}
