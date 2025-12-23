import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

void showAvatarBottomSheetAuth(
  BuildContext context, {
  required Function(ImageSource source) onPick,
  VoidCallback? onDelete,
}) {
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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              "Chọn ảnh đại diện",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Iconsax.gallery),
              title: const Text("Chọn từ thư viện"),
              onTap: () {
                Get.back();
                onPick(ImageSource.gallery);
              },
            ),

            ListTile(
              leading: const Icon(Iconsax.camera),
              title: const Text("Chụp ảnh mới"),
              onTap: () {
                Get.back();
                onPick(ImageSource.camera);
              },
            ),

            if (onDelete != null)
              ListTile(
                leading: const Icon(Iconsax.trash, color: Colors.red),
                title: const Text(
                  "Xoá ảnh",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Get.back();
                  onDelete();
                },
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
