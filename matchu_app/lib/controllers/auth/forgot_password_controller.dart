import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

class ForgotPasswordController extends GetxController {
  final emailC = TextEditingController();
  final isLoading = false.obs;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendResetEmail() async {
    final email = emailC.text.trim();

    if (email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar("Lỗi", "Vui lòng nhập email hợp lệ");
      return;
    }

    isLoading.value = true;

    try {
      await _auth.sendPasswordResetEmail(email: email);

      Get.snackbar(
        "Đã gửi thành công",
        "Vui lòng kiểm tra email để đặt lại mật khẩu",
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      );

      // 🔥 CHỜ USER NHÌN THẤY RỒI MỚI QUAY VỀ
      await Future.delayed(const Duration(seconds: 2));

      Get.offAllNamed('/');
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        "Lỗi",
        firebaseErrorToVietnamese(e.code),
      );
    }

  }

  @override
  void onClose() {
    emailC.dispose();
    super.onClose();
  }
}
