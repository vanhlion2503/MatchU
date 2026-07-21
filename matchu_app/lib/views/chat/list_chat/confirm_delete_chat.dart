import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';

Future<void> showConfirmDeleteChat({required VoidCallback onConfirm}) async {
  await Get.dialog(
    AlertDialog(
      title: Text("Xóa cuộc trò chuyện?".tr),
      content: Text(
        "Tin nhắn sẽ bị xóa vĩnh viễn khỏi tài khoản của bạn nhưng vẫn hiển thị với người kia. Tin nhắn mới từ họ sẽ xuất hiện như một cuộc trò chuyện mới."
            .tr,
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text("Hủy".tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: () {
            Get.back();
            onConfirm();
          },
          child: Text("Xóa".tr),
        ),
      ],
    ),
  );
}
