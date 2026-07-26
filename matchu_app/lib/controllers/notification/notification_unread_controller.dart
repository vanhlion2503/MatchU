import 'dart:async';

import 'package:get/get.dart';
import 'package:matchu_app/services/notification/notification_repository.dart';

/// Keeps the unread notification count available to every widget on the main
/// screen without opening multiple Firestore listeners.
class NotificationUnreadController extends GetxController {
  NotificationUnreadController({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  final RxInt unreadCount = 0.obs;
  StreamSubscription<int>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _bindUnreadCount();
  }

  void _bindUnreadCount() {
    _subscription?.cancel();
    _subscription = _repository.watchUnreadCount().listen(
      (count) => unreadCount.value = count < 0 ? 0 : count,
      onError: (_) {
        unreadCount.value = 0;
      },
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _subscription = null;
    super.onClose();
  }
}
