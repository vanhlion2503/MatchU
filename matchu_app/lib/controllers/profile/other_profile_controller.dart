import 'dart:async';

import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_restrictions_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/services/user/user_service.dart';

class OtherProfileController extends GetxController {
  OtherProfileController(this.userId);

  final UserService _userService = UserService();
  final PostRestrictionService _restrictionService = PostRestrictionService();

  late String userId;
  Rx<UserModel?> user = Rx<UserModel?>(null);
  RxBool isFollowing = false.obs;
  RxBool isLoadingFollowing = true.obs;
  RxBool isLoadingBlockState = true.obs;
  RxBool canMessage = false.obs;
  RxBool isBlocked = false.obs;
  RxBool isBlockedByUser = false.obs;
  RxBool isBlocking = false.obs;

  StreamSubscription<UserModel?>? _userSub;

  String get currentUid => _userService.uid;

  bool get hasBlockRelationship => isBlocked.value || isBlockedByUser.value;

  @override
  void onInit() {
    super.onInit();
    loadUserRealtime();
    unawaited(loadBlockState());
  }

  void loadUserRealtime() {
    _userSub?.cancel();
    _userSub = _userService
        .streamUser(userId)
        .listen(
          (userdata) {
            user.value = userdata;
            isLoadingFollowing.value = false;

            if (userdata != null) {
              canMessage.value =
                  !hasBlockRelationship &&
                  userdata.followers.contains(currentUid);
              unawaited(_loadFollowingState());
            }
          },
          onError: (_) {
            isLoadingFollowing.value = false;
          },
        );
  }

  Future<void> _loadFollowingState() async {
    try {
      isFollowing.value = await _userService
          .isFollowing(userId)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Keep the realtime profile usable when this secondary read fails.
    } finally {
      isLoadingFollowing.value = false;
    }
  }

  Future<void> loadBlockState() async {
    isLoadingBlockState.value = true;
    try {
      final states = await Future.wait([
        _restrictionService.isUserBlocked(userId),
        _restrictionService.isBlockedByUser(userId),
      ]).timeout(const Duration(seconds: 12));
      isBlocked.value = states[0];
      isBlockedByUser.value = states[1];
      if (hasBlockRelationship) {
        canMessage.value = false;
      }
    } catch (_) {
      // Profile content can still be shown when this secondary check fails.
    } finally {
      isLoadingBlockState.value = false;
    }
  }

  Future<bool> blockUser() async {
    final targetUser = user.value;
    if (targetUser == null || isBlocking.value) return false;

    isBlocking.value = true;
    try {
      final restrictionsController =
          Get.isRegistered<PostRestrictionsController>()
              ? Get.find<PostRestrictionsController>()
              : Get.put(PostRestrictionsController());
      final blocked = await restrictionsController.blockUser(targetUser);
      if (blocked) {
        _removeCurrentUserFromTargetRelations(targetUser);
        isBlocked.value = true;
        isFollowing.value = false;
        canMessage.value = false;
      }
      return blocked;
    } finally {
      isBlocking.value = false;
    }
  }

  Future<void> follow() async {
    if (hasBlockRelationship) return;
    await _userService.followUser(userId);
    isFollowing.value = true;
  }

  Future<void> unfollow() async {
    await _userService.unfollowUser(userId);
    isFollowing.value = false;
  }

  void _removeCurrentUserFromTargetRelations(UserModel targetUser) {
    final normalizedCurrentUid = currentUid.trim();
    if (normalizedCurrentUid.isEmpty) return;

    user.value = targetUser.copyWith(
      followers: targetUser.followers
          .where((id) => id.trim() != normalizedCurrentUid)
          .toList(growable: false),
      following: targetUser.following
          .where((id) => id.trim() != normalizedCurrentUid)
          .toList(growable: false),
    );
  }

  int get age {
    final u = user.value;
    if (u == null || u.birthday == null) return 0;

    final birthday = u.birthday!;
    final now = DateTime.now();

    int age = now.year - birthday.year;

    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    return age;
  }

  @override
  void onClose() {
    _userSub?.cancel();
    super.onClose();
  }
}
