import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_restrictions_controller.dart';
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
  final actingNotificationIds = <String>{}.obs;
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

  Future<void> deleteNotification(AppNotificationModel notification) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('X\u00F3a th\u00F4ng b\u00E1o?'),
        content: const Text(
          'Th\u00F4ng b\u00E1o n\u00E0y s\u1EBD b\u1ECB x\u00F3a kh\u1ECFi danh s\u00E1ch c\u1EE7a b\u1EA1n.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('H\u1EE7y'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('X\u00F3a'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _runNotificationAction(
      notification.id,
      () => _repository.deleteNotification(notification.id),
      successMessage: '\u0110\u00E3 x\u00F3a th\u00F4ng b\u00E1o.',
      errorMessage: 'Ch\u01B0a th\u1EC3 x\u00F3a th\u00F4ng b\u00E1o n\u00E0y.',
    );
  }

  Future<void> toggleReadState(AppNotificationModel notification) async {
    final successMessage =
        notification.isUnread
            ? '\u0110\u00E3 \u0111\u00E1nh d\u1EA5u \u0111\u00E3 \u0111\u1ECDc.'
            : '\u0110\u00E3 \u0111\u00E1nh d\u1EA5u ch\u01B0a \u0111\u1ECDc.';

    await _runNotificationAction(
      notification.id,
      () => _repository.toggleReadState(notification),
      successMessage: successMessage,
      errorMessage:
          'Ch\u01B0a th\u1EC3 c\u1EADp nh\u1EADt tr\u1EA1ng th\u00E1i th\u00F4ng b\u00E1o.',
    );
  }

  Future<void> muteAuthor(AppNotificationModel notification) async {
    final didMute = await _runNotificationAction(
      notification.id,
      () => _repository.muteAuthorFromNotification(notification),
      successMessage:
          '\u0110\u00E3 t\u1EAFt th\u00F4ng b\u00E1o t\u1EEB ng\u01B0\u1EDDi n\u00E0y.',
      errorMessage:
          'Ch\u01B0a th\u1EC3 t\u1EAFt th\u00F4ng b\u00E1o t\u1EEB ng\u01B0\u1EDDi n\u00E0y.',
    );

    if (didMute && Get.isRegistered<PostRestrictionsController>()) {
      await Get.find<PostRestrictionsController>()
          .loadMutedNotificationAuthors();
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

  Future<bool> _runNotificationAction(
    String notificationId,
    Future<void> Function() action, {
    required String successMessage,
    required String errorMessage,
  }) async {
    final normalizedId = notificationId.trim();
    if (normalizedId.isEmpty || actingNotificationIds.contains(normalizedId)) {
      return false;
    }

    actingNotificationIds.add(normalizedId);
    try {
      await action();
      Get.snackbar(
        'Th\u00F4ng b\u00E1o',
        successMessage,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return true;
    } catch (error) {
      final message = error is StateError ? error.message : errorMessage;
      Get.snackbar(
        'L\u1ED7i',
        message.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return false;
    } finally {
      actingNotificationIds.remove(normalizedId);
    }
  }
}
