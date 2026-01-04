import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/profile_snap_shot.dart';
import 'package:matchu_app/services/user/account_service.dart';

enum DobField { day, month, year }

class AccountSettingsController extends GetxController {
  final fullnameC = TextEditingController();
  final nicknameC = TextEditingController();

  final selectedGender = ''.obs;

  // ===== DOB STATE =====
  final selectedDobField = Rxn<DobField>();
  final selectedDay = RxnInt();
  final selectedMonth = RxnInt();
  final selectedYear = RxnInt();
  final selectedBirthday = Rx<DateTime?>(null);

  final isSaving = false.obs;

  final _service = AccountService();

  final isLoadingInitial = true.obs;
  ProfileSnapshot? _original;

  @override
  void onInit() {
    super.onInit();
    loadCurrentUser(); // 👈 BẮT BUỘC
  }

  Future<void> loadCurrentUser() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      final data = snap.data()!;

      fullnameC.text = data['fullname'] ?? '';
      nicknameC.text = data['nickname'] ?? '';
      selectedGender.value = data['gender'] ?? '';

      final birthday = DateTime.parse(data['birthday']);
      selectedBirthday.value = birthday;
      selectedDay.value = birthday.day;
      selectedMonth.value = birthday.month;
      selectedYear.value = birthday.year;

      _original = ProfileSnapshot(
        fullname: fullnameC.text,
        nickname: nicknameC.text,
        gender: selectedGender.value,
        birthday: birthday,
      );
    } finally {
      isLoadingInitial.value = false;
    }
  }

  bool get hasChanged {
    if (_original == null) return false;

    return fullnameC.text.trim() != _original!.fullname ||
        nicknameC.text.trim() != _original!.nickname ||
        selectedGender.value != _original!.gender ||
        selectedBirthday.value != _original!.birthday;
  }

  // ===== GHÉP NGÀY SINH =====
  void updateBirthdayIfReady() {
    if (selectedDay.value == null ||
        selectedMonth.value == null ||
        selectedYear.value == null) return;

    final d = selectedDay.value!;
    final m = selectedMonth.value!;
    final y = selectedYear.value!;

    final lastDay = DateTime(y, m + 1, 0).day;
    if (d > lastDay) {
      selectedDay.value = lastDay;
    }

    selectedBirthday.value = DateTime(
      y,
      m,
      selectedDay.value!,
    );
  }

  Future<void> save() async {
    final fullname = fullnameC.text.trim();
    final nickname = nicknameC.text.trim();
    final gender = selectedGender.value;
    final birthday = selectedBirthday.value;

    if (fullname.isEmpty) {
      Get.snackbar("Lỗi", "Họ tên không được để trống");
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(nickname)) {
      Get.snackbar(
        "Lỗi",
        "Nickname chỉ gồm chữ không dấu, số, dấu gạch dưới (_)",
      );
      return;
    }

    if (!['male', 'female', 'other'].contains(gender)) {
      Get.snackbar("Lỗi", "Vui lòng chọn giới tính");
      return;
    }

    if (birthday == null) {
      Get.snackbar("Lỗi", "Vui lòng chọn ngày sinh");
      return;
    }

    final age = DateTime.now().year - birthday.year;
    if (age < 18) {
      Get.snackbar("Lỗi", "Bạn phải đủ 18 tuổi");
      return;
    }

    if (!await _service.isNicknameUnique(nickname)) {
      Get.snackbar("Lỗi", "Nickname đã được sử dụng");
      return;
    }

    isSaving.value = true;
    try {
      await _service.updateBasicProfile(
        fullname: fullname,
        nickname: nickname,
        gender: gender,
        birthday: birthday,
      );
      Get.snackbar("Thành công", "Đã cập nhật hồ sơ");
    } catch (e) {
      Get.snackbar("Lỗi", e.toString());
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    fullnameC.dispose();
    nicknameC.dispose();
    super.onClose();
  }
}
