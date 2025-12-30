import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/user/presence_service.dart';

class AppLifecycleController extends GetxController
    with WidgetsBindingObserver {

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // ✅ App mở → online
    PresenceService.setOnline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ✅ quay lại app → online lại
      PresenceService.setOnline();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
