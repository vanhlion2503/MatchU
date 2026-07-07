import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/notification/app_notification_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/services/notification/notification_repository.dart';

enum NotificationInboxFilter { all, unread }

class NotificationInboxController extends GetxController {
  NotificationInboxController({
    NotificationRepository? repository,
    PostService? postService,
  }) : _repository = repository ?? NotificationRepository(),
       _postService = postService ?? PostService();

  final NotificationRepository _repository;
  final PostService _postService;

  final notifications = <AppNotificationModel>[].obs;
  final unreadCount = 0.obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final openingNotificationId = RxnString();
  final selectedFilter = NotificationInboxFilter.all.obs;
  final visibleLimit = 10.obs;

  StreamSubscription<List<AppNotificationModel>>? _notificationsSub;
  StreamSubscription<int>? _unreadSub;

  static const int _pageSize = 10;

  List<AppNotificationModel> get filteredNotifications {
    if (selectedFilter.value == NotificationInboxFilter.unread) {
      return notifications.where((item) => item.isUnread).toList();
    }
    return notifications;
  }

  List<AppNotificationModel> get visibleNotifications =>
      filteredNotifications.take(visibleLimit.value).toList();

  bool get hasMoreNotifications =>
      visibleLimit.value < filteredNotifications.length;

  @override
  void onInit() {
    super.onInit();
    _bindNotifications();
    _bindUnreadCount();
  }

  @override
  void onClose() {
    _notificationsSub?.cancel();
    _unreadSub?.cancel();
    super.onClose();
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead(notifications);
    } catch (_) {
      Get.snackbar(
        'Thông báo',
        'Chưa thể đánh dấu tất cả là đã đọc.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  void selectFilter(NotificationInboxFilter filter) {
    selectedFilter.value = filter;
    visibleLimit.value = _pageSize;
  }

  void showMoreNotifications() {
    visibleLimit.value += _pageSize;
  }

  Future<void> openNotification(AppNotificationModel notification) async {
    if (openingNotificationId.value != null) return;

    openingNotificationId.value = notification.id;
    try {
      if (notification.isUnread) {
        await _repository.markAsRead(notification.id);
      }

      if (notification.canOpenPost) {
        final post = await _postService.fetchPostById(notification.postId!);
        if (post == null) {
          Get.snackbar(
            'Bài viết không khả dụng',
            'Bài viết đã bị xóa hoặc bạn không còn quyền xem.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
          return;
        }

        await Get.toNamed(
          AppRouter.postDetail,
          arguments: PostDetailRouteArgs(post: post),
        );
        return;
      }

      if (notification.type == AppNotificationType.moderationPenalty) {
        await Get.toNamed(AppRouter.reputation);
      }
    } catch (_) {
      Get.snackbar(
        'Thông báo',
        'Không thể mở thông báo này.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      openingNotificationId.value = null;
    }
  }

  void _bindNotifications() {
    _notificationsSub = _repository.watchNotifications().listen(
      (items) {
        notifications.assignAll(items);
        errorMessage.value = null;
        isLoading.value = false;
      },
      onError: (_) {
        errorMessage.value = 'Không thể tải danh sách thông báo.';
        isLoading.value = false;
      },
    );
  }

  void _bindUnreadCount() {
    _unreadSub = _repository.watchUnreadCount().listen(
      unreadCount.call,
      onError: (_) => unreadCount.value = 0,
    );
  }
}
