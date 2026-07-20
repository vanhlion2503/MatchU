import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/profile/profile_privacy_controller.dart';
import 'package:matchu_app/models/profile_privacy_settings.dart';

class FollowingListPrivacyView extends GetView<ProfilePrivacyController> {
  const FollowingListPrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Danh sách đang theo dõi'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = controller.errorMessage.value;
        if (error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: controller.loadSettings,
                    child: Text('Thử lại'.tr),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Chọn người có thể xem danh sách tài khoản mà bạn đang theo dõi.'
                    .tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            _VisibilityTile(
              value: FollowingListVisibility.everyone,
              title: 'Mọi người'.tr,
              subtitle:
                  'Ai cũng có thể xem danh sách đang theo dõi của bạn.'.tr,
            ),
            _VisibilityTile(
              value: FollowingListVisibility.followers,
              title: 'Người theo dõi'.tr,
              subtitle: 'Chỉ người đang theo dõi bạn mới có thể xem.'.tr,
            ),
            _VisibilityTile(
              value: FollowingListVisibility.onlyMe,
              title: 'Chỉ mình tôi'.tr,
              subtitle: 'Chỉ bạn mới có thể xem danh sách này.'.tr,
            ),
          ],
        );
      }),
    );
  }
}

class _VisibilityTile extends GetView<ProfilePrivacyController> {
  const _VisibilityTile({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final FollowingListVisibility value;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.followingListVisibility.value == value;
    final enabled = !controller.isSavingFollowingVisibility.value;
    return ListTile(
      onTap:
          enabled
              ? () => controller.updateFollowingListVisibility(value)
              : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
