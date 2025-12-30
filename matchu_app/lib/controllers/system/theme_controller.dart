import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/material.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = "themeMode"; // "light" | "dark"

  // Lưu trạng thái hiện tại
  RxString themeMode = "light".obs;

  @override
  void onInit() {
    themeMode.value = _box.read(_key) ?? "light";
    super.onInit();
  }

  ThemeMode get currentTheme =>
      themeMode.value == "dark" ? ThemeMode.dark : ThemeMode.light;

  void setLight() {
    themeMode.value = "light";
    _box.write(_key, "light");
    Get.changeThemeMode(ThemeMode.light);
  }

  void setDark() {
    themeMode.value = "dark";
    _box.write(_key, "dark");
    Get.changeThemeMode(ThemeMode.dark);
  }
}
