import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';

import 'package:matchu_app/controllers/auth/avatar_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

/// ===============================
/// Avatar Bottom Sheet
/// ===============================
void showAvatarBottomSheet(BuildContext context) {
  final AvatarController c = Get.find<AvatarController>();

  Get.bottomSheet(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== DRAG HANDLE =====
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // ===== TITLE =====
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Cập nhật ảnh đại diện",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            const Divider(),

            // ===== GALLERY =====
            _AvatarActionItem(
              icon: Iconsax.gallery,
              label: "Chọn ảnh từ thư viện",
              onTap: () {
                Get.back();
                c.pickAvatar(ImageSource.gallery);
              },
            ),

            // ===== CAMERA =====
            _AvatarActionItem(
              icon: Iconsax.camera,
              label: "Chụp ảnh mới",
              onTap: () {
                Get.back();
                c.pickAvatar(ImageSource.camera);
              },
            ),

            // ===== DELETE =====
            Obx(() {
              final hasAvatar =
                  c.user.value != null && c.user.value!.avatarUrl.isNotEmpty;

              if (!hasAvatar) return const SizedBox.shrink();

              return _AvatarActionItem(
                icon: Iconsax.trash,
                label: "Xoá ảnh đại diện",
                color: AppTheme.errorColor,
                onTap: () {
                  Get.back();
                  _confirmDeleteAvatar(context, c);
                },
              );
            }),

            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

/// ===============================
/// Confirm delete dialog
/// ===============================
void _confirmDeleteAvatar(
  BuildContext context,
  AvatarController controller,
) {
  Get.dialog(
    AlertDialog(
      title: const Text("Xoá ảnh đại diện"),
      content: const Text(
        "Bạn có chắc chắn muốn xoá ảnh đại diện hiện tại không?",
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text("Huỷ"),
        ),
        TextButton(
          onPressed: () {
            Get.back();
            controller.deleteAvatar();
          },
          child: const Text(
            "Xoá",
            style: TextStyle(color: AppTheme.errorColor),
          ),
        ),
      ],
    ),
  );
}

/// ===============================
/// Item widget
/// ===============================
class _AvatarActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _AvatarActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: color ?? theme.iconTheme.color,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
