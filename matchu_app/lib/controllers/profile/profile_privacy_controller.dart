import 'package:get/get.dart';
import 'package:matchu_app/models/profile_privacy_settings.dart';
import 'package:matchu_app/repositories/profile_privacy/profile_privacy_repository.dart';

class ProfilePrivacyController extends GetxController {
  ProfilePrivacyController({required ProfilePrivacyRepository repository})
    : _repository = repository;

  final ProfilePrivacyRepository _repository;

  final followingListVisibility = FollowingListVisibility.everyone.obs;
  final isPrivateAccount = false.obs;
  final isLoading = true.obs;
  final isSavingFollowingVisibility = false.obs;
  final isSavingPrivateAccount = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final settings = await _repository.getCurrentSettings();
      followingListVisibility.value = settings.followingListVisibility;
      isPrivateAccount.value = settings.isPrivateAccount;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateFollowingListVisibility(
    FollowingListVisibility value,
  ) async {
    if (isSavingFollowingVisibility.value ||
        value == followingListVisibility.value) {
      return;
    }

    final previous = followingListVisibility.value;
    followingListVisibility.value = value;
    isSavingFollowingVisibility.value = true;
    try {
      await _repository.setFollowingListVisibility(value);
    } catch (_) {
      followingListVisibility.value = previous;
      Get.snackbar('Lỗi'.tr, 'Không thể cập nhật quyền riêng tư.'.tr);
    } finally {
      isSavingFollowingVisibility.value = false;
    }
  }

  Future<void> updatePrivateAccount(bool enabled) async {
    if (isSavingPrivateAccount.value || enabled == isPrivateAccount.value) {
      return;
    }

    final previous = isPrivateAccount.value;
    isPrivateAccount.value = enabled;
    isSavingPrivateAccount.value = true;
    try {
      await _repository.setPrivateAccount(enabled);
    } catch (_) {
      isPrivateAccount.value = previous;
      Get.snackbar('Lỗi'.tr, 'Không thể cập nhật quyền riêng tư.'.tr);
    } finally {
      isSavingPrivateAccount.value = false;
    }
  }
}
