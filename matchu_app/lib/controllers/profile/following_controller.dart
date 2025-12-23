import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class FollowingController extends GetxController {
  final UserService _userService = UserService();
  final String userId;

  FollowingController(this.userId);

  RxList<UserModel> users = <UserModel>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadFollowing();
  }

  Future<void> loadFollowing() async {
    isLoading.value = true;

    final targetUser = await _userService.getUser(userId);
    if (targetUser == null) {
      isLoading.value = false;
      return;
    }

    List<UserModel> list = [];
    for (String id in targetUser.following) {
      final u = await _userService.getUser(id);
      if (u != null) list.add(u);
    }

    users.assignAll(list);
    isLoading.value = false;
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
