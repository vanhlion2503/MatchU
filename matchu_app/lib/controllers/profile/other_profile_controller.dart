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
  RxBool canMessage = false.obs;
  RxBool isBlocked = false.obs;
  RxBool isBlocking = false.obs;

  StreamSubscription<UserModel?>? _userSub;

  String get currentUid => _userService.uid;

  @override
  void onInit() {
    super.onInit();
    loadUserRealtime();
    unawaited(loadBlockState());
  }

  void loadUserRealtime() {
    _userSub?.cancel();
    _userSub = _userService.streamUser(userId).listen((userdata) async {
      user.value = userdata;
      isLoadingFollowing.value = false;

      if (userdata != null) {
        isFollowing.value = await _userService.isFollowing(userId);
        canMessage.value =
            !isBlocked.value && userdata.followers.contains(currentUid);
      }
    });
  }

  Future<void> loadBlockState() async {
    final blocked = await _restrictionService.isUserBlocked(userId);
    isBlocked.value = blocked;
    if (blocked) {
      canMessage.value = false;
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
        isBlocked.value = true;
        canMessage.value = false;
      }
      return blocked;
    } finally {
      isBlocking.value = false;
    }
  }

  Future<void> follow() async {
    if (isBlocked.value) return;
    await _userService.followUser(userId);
    isFollowing.value = true;
  }

  Future<void> unfollow() async {
    await _userService.unfollowUser(userId);
    isFollowing.value = false;
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
