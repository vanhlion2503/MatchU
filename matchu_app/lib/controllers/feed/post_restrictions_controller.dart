import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/controllers/profile/followers_controller.dart';
import 'package:matchu_app/controllers/profile/following_controller.dart';
import 'package:matchu_app/controllers/search/search_user_controller.dart';
import 'package:matchu_app/models/feed/blocked_user_model.dart';
import 'package:matchu_app/models/feed/hidden_post_author_model.dart';
import 'package:matchu_app/models/notification/muted_notification_author_model.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/services/notification/notification_repository.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum PostRestrictionsStatus { initial, loading, success, empty, error }

class PostRestrictionsController extends GetxController {
  PostRestrictionsController({
    PostRestrictionService? restrictionService,
    NotificationRepository? notificationRepository,
  }) : _restrictionService = restrictionService ?? PostRestrictionService(),
       _notificationRepository =
           notificationRepository ?? NotificationRepository();

  final PostRestrictionService _restrictionService;
  final NotificationRepository _notificationRepository;

  final RxList<HiddenPostAuthorModel> hiddenPostAuthors =
      <HiddenPostAuthorModel>[].obs;
  final RxList<BlockedUserModel> blockedUsers = <BlockedUserModel>[].obs;
  final RxList<MutedNotificationAuthorModel> mutedNotificationAuthors =
      <MutedNotificationAuthorModel>[].obs;
  final RxSet<String> blockedUserIds = <String>{}.obs;
  final Rx<PostRestrictionsStatus> hiddenAuthorsStatus =
      PostRestrictionsStatus.initial.obs;
  final Rx<PostRestrictionsStatus> blockedUsersStatus =
      PostRestrictionsStatus.initial.obs;
  final Rx<PostRestrictionsStatus> mutedNotificationAuthorsStatus =
      PostRestrictionsStatus.initial.obs;
  final RxnString errorMessage = RxnString();
  final RxSet<String> unhidingAuthorIds = <String>{}.obs;
  final RxSet<String> blockingUserIds = <String>{}.obs;
  final RxSet<String> unblockingUserIds = <String>{}.obs;
  final RxSet<String> unmutingAuthorIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadBlockedUsers());
    unawaited(loadHiddenPostAuthors());
    unawaited(loadMutedNotificationAuthors());
  }

  bool isUserBlocked(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;
    return blockedUserIds.contains(normalizedUserId);
  }

  bool isAuthorUnhiding(String authorId) {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty) return false;
    return unhidingAuthorIds.contains(normalizedAuthorId);
  }

  bool isUserBlocking(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;
    return blockingUserIds.contains(normalizedUserId);
  }

  bool isUserUnblocking(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;
    return unblockingUserIds.contains(normalizedUserId);
  }

  bool isNotificationAuthorUnmuting(String authorId) {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty) return false;
    return unmutingAuthorIds.contains(normalizedAuthorId);
  }

  Future<void> loadBlockedUsers() async {
    if (blockedUsersStatus.value == PostRestrictionsStatus.loading) return;

    blockedUsersStatus.value = PostRestrictionsStatus.loading;
    errorMessage.value = null;

    try {
      final items = await _restrictionService.fetchBlockedUsers();
      blockedUsers.assignAll(items);
      blockedUserIds
        ..clear()
        ..addAll(items.map((item) => item.blockedUserId.trim()));
      blockedUserIds.removeWhere((userId) => userId.isEmpty);
      blockedUsersStatus.value =
          items.isEmpty
              ? PostRestrictionsStatus.empty
              : PostRestrictionsStatus.success;
    } catch (error) {
      errorMessage.value = _mapError(error);
      blockedUsersStatus.value = PostRestrictionsStatus.error;
    }
  }

  Future<void> loadHiddenPostAuthors() async {
    if (hiddenAuthorsStatus.value == PostRestrictionsStatus.loading) return;

    hiddenAuthorsStatus.value = PostRestrictionsStatus.loading;
    errorMessage.value = null;

    try {
      final items = await _restrictionService.fetchHiddenPostAuthors();
      hiddenPostAuthors.assignAll(items);
      hiddenAuthorsStatus.value =
          items.isEmpty
              ? PostRestrictionsStatus.empty
              : PostRestrictionsStatus.success;
    } catch (error) {
      errorMessage.value = _mapError(error);
      hiddenAuthorsStatus.value = PostRestrictionsStatus.error;
    }
  }

  Future<void> loadMutedNotificationAuthors() async {
    if (mutedNotificationAuthorsStatus.value ==
        PostRestrictionsStatus.loading) {
      return;
    }

    mutedNotificationAuthorsStatus.value = PostRestrictionsStatus.loading;
    errorMessage.value = null;

    try {
      final items = await _notificationRepository.fetchMutedAuthors();
      mutedNotificationAuthors.assignAll(items);
      mutedNotificationAuthorsStatus.value =
          items.isEmpty
              ? PostRestrictionsStatus.empty
              : PostRestrictionsStatus.success;
    } catch (error) {
      errorMessage.value = _mapError(error);
      mutedNotificationAuthorsStatus.value = PostRestrictionsStatus.error;
    }
  }

  Future<bool> blockUser(UserModel targetUser) async {
    final blockedUserId = targetUser.uid.trim();
    if (blockedUserId.isEmpty || blockingUserIds.contains(blockedUserId)) {
      return false;
    }

    blockingUserIds.add(blockedUserId);

    try {
      await _restrictionService.blockUser(targetUser);

      blockedUserIds.add(blockedUserId);
      blockedUsers.removeWhere(
        (item) => item.blockedUserId.trim() == blockedUserId,
      );
      blockedUsers.insert(
        0,
        BlockedUserModel.fromUser(targetUser, blockedAt: DateTime.now()),
      );
      blockedUsersStatus.value = PostRestrictionsStatus.success;

      _notifyUserBlocked(blockedUserId);

      Get.snackbar(
        'Th\u00F4ng b\u00E1o',
        '\u0110\u00E3 ch\u1EB7n ng\u01B0\u1EDDi d\u00F9ng n\u00E0y.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );

      return true;
    } catch (error) {
      _showError(_mapError(error));
      return false;
    } finally {
      blockingUserIds.remove(blockedUserId);
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final normalizedBlockedUserId = blockedUserId.trim();
    if (normalizedBlockedUserId.isEmpty ||
        unblockingUserIds.contains(normalizedBlockedUserId)) {
      return;
    }

    unblockingUserIds.add(normalizedBlockedUserId);

    try {
      await _restrictionService.unblockUser(normalizedBlockedUserId);
      blockedUserIds.remove(normalizedBlockedUserId);
      blockedUsers.removeWhere(
        (item) => item.blockedUserId.trim() == normalizedBlockedUserId,
      );

      if (blockedUsers.isEmpty) {
        blockedUsersStatus.value = PostRestrictionsStatus.empty;
      } else {
        blockedUsersStatus.value = PostRestrictionsStatus.success;
      }

      _notifyUserUnblocked(normalizedBlockedUserId);

      Get.snackbar(
        'Th\u00F4ng b\u00E1o',
        '\u0110\u00E3 g\u1EE1 ch\u1EB7n ng\u01B0\u1EDDi d\u00F9ng n\u00E0y.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      unblockingUserIds.remove(normalizedBlockedUserId);
    }
  }

  Future<void> unhideAuthor(String authorId) async {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty ||
        unhidingAuthorIds.contains(normalizedAuthorId)) {
      return;
    }

    unhidingAuthorIds.add(normalizedAuthorId);

    try {
      await _restrictionService.unhidePostAuthor(normalizedAuthorId);
      hiddenPostAuthors.removeWhere(
        (item) => item.authorId.trim() == normalizedAuthorId,
      );

      if (hiddenPostAuthors.isEmpty) {
        hiddenAuthorsStatus.value = PostRestrictionsStatus.empty;
      } else {
        hiddenAuthorsStatus.value = PostRestrictionsStatus.success;
      }

      if (Get.isRegistered<FeedController>()) {
        Get.find<FeedController>().applyHiddenPostAuthorRemoved(
          normalizedAuthorId,
        );
      }

      Get.snackbar(
        'Th\u00F4ng b\u00E1o',
        '\u0110\u00E3 b\u1ECF \u1EA9n b\u00E0i vi\u1EBFt t\u1EEB ng\u01B0\u1EDDi n\u00E0y.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      unhidingAuthorIds.remove(normalizedAuthorId);
    }
  }

  Future<void> unmuteNotificationAuthor(String authorId) async {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty ||
        unmutingAuthorIds.contains(normalizedAuthorId)) {
      return;
    }

    unmutingAuthorIds.add(normalizedAuthorId);

    try {
      await _notificationRepository.unmuteAuthor(normalizedAuthorId);
      mutedNotificationAuthors.removeWhere(
        (item) => item.authorId.trim() == normalizedAuthorId,
      );

      mutedNotificationAuthorsStatus.value =
          mutedNotificationAuthors.isEmpty
              ? PostRestrictionsStatus.empty
              : PostRestrictionsStatus.success;

      Get.snackbar(
        'Th\u00F4ng b\u00E1o',
        '\u0110\u00E3 b\u1EADt l\u1EA1i th\u00F4ng b\u00E1o t\u1EEB ng\u01B0\u1EDDi n\u00E0y.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      unmutingAuthorIds.remove(normalizedAuthorId);
    }
  }

  String _mapError(Object error) {
    if (error is FirebaseException) {
      return firebaseErrorToVietnamese(error.code);
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return 'Kh\u00F4ng th\u1EC3 t\u1EA3i Danh s\u00E1ch h\u1EA1n ch\u1EBF l\u00FAc n\u00E0y. Vui l\u00F2ng th\u1EED l\u1EA1i.';
  }

  void _showError(String message) {
    Get.snackbar(
      'L\u1ED7i',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _notifyUserBlocked(String userId) {
    if (Get.isRegistered<FeedController>()) {
      unawaited(Get.find<FeedController>().applyUserBlocked(userId));
    }
    if (Get.isRegistered<SearchUserController>()) {
      Get.find<SearchUserController>().applyUserBlocked(userId);
    }
    if (Get.isRegistered<NearbyController>()) {
      Get.find<NearbyController>().applyUserBlocked(userId);
    }
    if (Get.isRegistered<ChatListController>()) {
      Get.find<ChatListController>().applyUserBlocked(userId);
    }
    if (Get.isRegistered<FollowersController>()) {
      Get.find<FollowersController>().applyUserBlocked(userId);
    }
    if (Get.isRegistered<FollowingController>()) {
      Get.find<FollowingController>().applyUserBlocked(userId);
    }
  }

  void _notifyUserUnblocked(String userId) {
    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().applyBlockedUserRemoved(userId);
    }
    if (Get.isRegistered<ChatListController>()) {
      Get.find<ChatListController>().applyUserUnblocked(userId);
    }
    if (Get.isRegistered<NearbyController>()) {
      unawaited(Get.find<NearbyController>().loadNearby(force: true));
    }
  }
}
