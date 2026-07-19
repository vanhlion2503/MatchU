import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/profile/profile_privacy_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class PrivateAccountView extends GetView<ProfilePrivacyController> {
  const PrivateAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tài khoản riêng tư'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = controller.errorMessage.value;
        if (error != null) {
          return Center(
            child: FilledButton(
              onPressed: controller.loadSettings,
              child: Text('Thử lại'.tr),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 38,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: const Icon(
                  Iconsax.lock,
                  color: AppTheme.primaryColor,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Tài khoản riêng tư'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Khi bật, chỉ những người đang theo dõi bạn mới có thể xem bài viết. Bạn luôn có thể xem bài viết của chính mình.'
                    .tr,
              ),
              value: controller.isPrivateAccount.value,
              onChanged:
                  controller.isSavingPrivateAccount.value
                      ? null
                      : controller.updatePrivateAccount,
            ),
            if (controller.isSavingPrivateAccount.value)
              const LinearProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              controller.isPrivateAccount.value
                  ? 'Tài khoản của bạn hiện đang ở chế độ riêng tư.'.tr
                  : 'Tài khoản của bạn đang hiển thị bài viết bình thường.'.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      }),
    );
  }
}
