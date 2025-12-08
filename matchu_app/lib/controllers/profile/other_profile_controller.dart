import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user_service.dart';

class OtherProfileController extends GetxController{
  final UserService _userService = UserService();

  late String userId;
  Rx<UserModel?> user = Rx<UserModel?>(null);
  RxBool isFollowing = false.obs;
  RxBool isLoadingFollowing = true.obs;

  OtherProfileController(this.userId);
  String get currentUid => _userService.uid;

  @override
  void onInit(){
    super.onInit();
    loadUserRealtime();
  }

  void loadUserRealtime(){
    _userService.streamUser(userId).listen((userdata) async{
      user.value = userdata;
      isLoadingFollowing.value = false;

      if(userdata != null){
        isFollowing.value = await _userService.isFollowing(userId);
      }
    });
  }
  Future<void> follow() async{
    await _userService.followUser(userId);
    isFollowing.value = true;
  }
  Future<void> unfollow() async{
    await _userService.unfollowUser(userId);
    isFollowing.value = false;
  }
}