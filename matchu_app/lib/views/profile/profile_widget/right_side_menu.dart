import 'package:matchu_app/translations/localized_material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart'; // nhớ import

import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/translations/translation_keys.dart';

class RightSideMenu {
  static void open(BuildContext context) {
    final authC = Get.find<AuthController>(); // ⬅️ THÊM DÒNG NÀY

    showGeneralDialog(
      context: context,
      barrierLabel: TranslationKeys.options.tr,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),

                                // ==== HỒ SƠ ====
                                sectionHeader(
                                  TranslationKeys.profileSection.tr,
                                ),
                                menuItem(
                                  icon: Iconsax.user,
                                  text: TranslationKeys.editProfile.tr,
                                  onTap: () {
                                    Get.back();
                                    Get.toNamed("/edit-profile");
                                  },
                                ),
                                menuItem(
                                  icon: Iconsax.lock,
                                  text: TranslationKeys.accountSecurity.tr,
                                  onTap: () {
                                    Get.toNamed("/account-security");
                                  },
                                ),
                                menuItem(
                                  icon: Iconsax.scan,
                                  text: TranslationKeys.myCode.tr,
                                  onTap: () {
                                    Get.back();
                                    Get.toNamed(
                                      AppRouter.profileQr,
                                      arguments: {'initialTab': 1},
                                    );
                                  },
                                ),
                                menuItem(
                                  icon: Iconsax.user_tag,
                                  text: TranslationKeys.verifyAccount.tr,
                                  onTap: () {
                                    Get.back();
                                    Get.toNamed("/face-verification");
                                  },
                                ),

                                divider(),

                                // ==== HOẠT ĐỘNG ====
                                sectionHeader(TranslationKeys.activity.tr),
                                menuItem(
                                  icon: Iconsax.notification,
                                  text: TranslationKeys.activityCenter.tr,
                                  onTap: () => Get.toNamed("/activity-center"),
                                ),
                                menuItem(
                                  icon: Iconsax.heart,
                                  text: TranslationKeys.likedYou.tr,
                                  onTap: () => Get.toNamed("/liked-you"),
                                ),
                                menuItem(
                                  icon: Iconsax.profile_2user,
                                  text: TranslationKeys.followingList.tr,
                                  onTap: () => Get.toNamed("/following-list"),
                                ),
                                menuItem(
                                  icon: Iconsax.user_remove,
                                  text: TranslationKeys.restrictionList.tr,
                                  onTap: () {
                                    Get.back();
                                    Get.toNamed(AppRouter.restrictionList);
                                  },
                                ),

                                divider(),

                                // ==== HỆ THỐNG ====
                                sectionHeader(TranslationKeys.system.tr),
                                menuItem(
                                  icon: Iconsax.setting_2,
                                  text: TranslationKeys.appSettings.tr,
                                  onTap: () => Get.toNamed("/app-settings"),
                                ),
                                menuItem(
                                  icon: Iconsax.moon,
                                  text: TranslationKeys.displayMode.tr,
                                  onTap: () {
                                    Get.back();
                                    Get.toNamed("/display-mode");
                                  },
                                ),
                                menuItem(
                                  icon: Iconsax.global,
                                  text: TranslationKeys.language.tr,
                                  onTap: () {
                                    Get.back();
                                    Get.toNamed(AppRouter.language);
                                  },
                                ),

                                const Spacer(),

                                // ==== ĐĂNG XUẤT ====
                                menuItem(
                                  icon: Icons.logout,
                                  text: TranslationKeys.logout.tr,
                                  danger: true,
                                  onTap: () {
                                    authC.logoutC();
                                  },
                                ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget divider() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Divider(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        );
      },
    );
  }

  // ===== PHẦN HEADER =====
  static Widget sectionHeader(String title) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  // ===== ITEM CÓ THỂ BẤM =====
  static Widget menuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger ? AppTheme.errorColor : AppTheme.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color:
                          danger
                              ? AppTheme.errorColor
                              : theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
