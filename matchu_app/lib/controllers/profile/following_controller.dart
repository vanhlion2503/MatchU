import 'package:get/get.dart';
import 'package:matchu_app/models/profile_privacy_settings.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/services/user/user_service.dart';

class FollowingController extends GetxController {
  final UserService _userService = UserService();
  final PostRestrictionService _restrictionService = PostRestrictionService();
  final String userId;

  FollowingController(this.userId);

  RxList<UserModel> users = <UserModel>[].obs;
  RxBool isLoading = false.obs;
  RxBool accessDenied = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadFollowing();
  }

  Future<void> loadFollowing() async {
    isLoading.value = true;
    accessDenied.value = false;
    try {
      final targetUser = await _userService.getUser(userId);
      if (targetUser == null) return;

      if (!await _canViewFollowingList(targetUser)) {
        users.clear();
        accessDenied.value = true;
        return;
      }

      final blockedUserIds = await _restrictionService.fetchBlockedUserIds();
      final list = <UserModel>[];
      for (final id in targetUser.following) {
        if (blockedUserIds.contains(id.trim())) continue;
        final user = await _userService.getUser(id);
        if (user != null) list.add(user);
      }

      users.assignAll(list);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _canViewFollowingList(UserModel targetUser) async {
    final currentUid = _userService.uid;
    final isOwner = currentUid == targetUser.uid;
    if (isOwner) return true;

    if (targetUser.followingListVisibility ==
        FollowingListVisibility.everyone) {
      return true;
    }
    if (targetUser.followingListVisibility == FollowingListVisibility.onlyMe) {
      return false;
    }

    // Check from the viewer's own `following` list. This is the direct answer
    // to "is the viewer following this profile?" and avoids reversing the
    // relationship with the profile owner's `followers` array.
    final isViewerFollowingOwner = await _userService.isFollowing(
      targetUser.uid,
    );
    return isViewerFollowingOwner;
  }

  void applyUserBlocked(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    users.removeWhere((user) => user.uid.trim() == normalizedUserId);
  }

  Future<void> follow(String uid) async {
    await _userService.followUser(uid);
    update();
  }

  Future<void> unfollow(String uid) async {
    await _userService.unfollowUser(uid);
    update();
  }
}
