import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:flutter/material.dart';


class SearchUserController extends GetxController {
  final UserService _userService = UserService();
  RxList<UserModel> results = <UserModel>[].obs;
  RxBool isLoading = false.obs;

  final searchFocus = FocusNode();
  final isFocused = false.obs;
  @override
  void onInit() {
    super.onInit();

    searchFocus.addListener(() {
      isFocused.value = searchFocus.hasFocus;
    });
  }

  @override
  void onClose() {
    searchFocus.dispose();
    super.onClose();
  }

  Future<void> searchUser(String keyword) async {
    keyword = keyword.trim();

    if (keyword.isEmpty) {
      results.clear();
      return;
    }

    isLoading.value = true;

    final data = await _userService.searchUsersByNickname(keyword);
    results.assignAll(data);

    isLoading.value = false;
  }
}
