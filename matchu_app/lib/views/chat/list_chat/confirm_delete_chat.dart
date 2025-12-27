import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';

Future<void> showConfirmDeleteChat({
  required VoidCallback onConfirm,
}) async {
  await Get.dialog(
    AlertDialog(
      title: const Text("Xóa cuộc trò chuyện?"),
      content: const Text(
        "Cuộc trò chuyện sẽ bị ẩn khỏi danh sách của bạn.",
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text("Hủy"),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
          ),
          onPressed: () {
            Get.back();
            onConfirm();
          },
          child: const Text("Xóa"),
        ),
      ],
    ),
  );
}
