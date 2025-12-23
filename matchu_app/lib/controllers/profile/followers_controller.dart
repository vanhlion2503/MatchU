import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class FollowersController extends GetxController{
  final UserService _userService = UserService();
  final String userId;

  RxList<UserModel> followers = RxList<UserModel>([]);
  RxBool isLoading = false.obs;

  FollowersController(this.userId);

  @override
  void onInit(){
    super.onInit();
    loadFollowers();
  }
  Future<void> loadFollowers() async {
    isLoading.value = true;
    final targetUser = await _userService.getUser(userId);
    if(targetUser == null){
      isLoading.value = false;
      return;
    }
    List<UserModel> list = [];
    for(String id in targetUser.followers){
      final u = await _userService.getUser(id);
      if (u != null) list.add(u);
    }
    followers.assignAll(list);
    isLoading.value = false;
  }
  
  Future<bool> isFollowingBack(String uid) async{
    return await _userService.isFollowing(uid);
  }

  Future<void> follow(String uid) async{
    await _userService.followUser(uid);
    update();
  }

  Future<void> unfollow(String uid) async {
    await _userService.unfollowUser(uid);
    update();
  }
}