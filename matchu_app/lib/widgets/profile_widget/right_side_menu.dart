import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart'; // nhớ import

class RightSideMenu {
  static void open(BuildContext context) {
    final authC = Get.find<AuthController>(); // ⬅️ THÊM DÒNG NÀY

    showGeneralDialog(
      context: context,
      barrierLabel: "Menu",
      barrierDismissible: true,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 280),

      pageBuilder: (_, __, ___) => const SizedBox.shrink(),

      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation);

        return Material(
          type: MaterialType.transparency,
          child: SlideTransition(
            position: slide,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: double.infinity,
                color: AppTheme.backgroundColor,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: 10),

                      // ==== HỒ SƠ ====
                      sectionHeader("Hồ sơ cá nhân"),
                      menuItem(
                        icon: Icons.person_outline,
                        text: "Chỉnh sửa hồ sơ",
                        onTap: () {
                          Get.toNamed("/edit-profile");
                        },
                      ),
                      menuItem(
                        icon: Icons.lock_outline,
                        text: "Tài khoản & Bảo mật",
                        onTap: () {
                          Get.toNamed("/account-security");
                        },
                      ),

                      Divider(color: AppTheme.borderColor),

                      // ==== HOẠT ĐỘNG ====
                      sectionHeader("Hoạt động"),
                      menuItem(
                        icon: Icons.notifications_none,
                        text: "Trung tâm hoạt động",
                        onTap: () => Get.toNamed("/activity-center"),
                      ),
                      menuItem(
                        icon: Icons.favorite_border,
                        text: "Người đã thích bạn",
                        onTap: () => Get.toNamed("/liked-you"),
                      ),
                      menuItem(
                        icon: Icons.group_outlined,
                        text: "Danh sách bạn đang theo dõi",
                        onTap: () => Get.toNamed("/following-list"),
                      ),

                      Divider(color: AppTheme.borderColor),

                      // ==== CÀI ĐẶT ====
                      sectionHeader("Hệ thống"),
                      menuItem(
                        icon: Icons.settings_outlined,
                        text: "Cài đặt ứng dụng",
                        onTap: () => Get.toNamed("/app-settings"),
                      ),

                      const Spacer(),

                      // ==== ĐĂNG XUẤT ====
                      menuItem(
                        icon: Icons.logout,
                        text: "Đăng xuất",
                        danger: true,
                        onTap: () {
                          Navigator.pop(context); // đóng menu
                          authC.logoutC();        // đăng xuất
                        },
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===== PHẦN HEADER =====
  static Widget sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ===== ITEM CÓ THỂ BẤM =====
  static Widget menuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger ? Colors.red : AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: danger
                      ? Colors.red
                      : AppTheme.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
