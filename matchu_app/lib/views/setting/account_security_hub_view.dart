import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/user/account_security_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/translation_keys.dart';

/// Trang tổng quan. Các thao tác nhạy cảm chỉ xuất hiện sau khi người dùng
/// chủ động mở đúng nhóm chức năng.
class AccountSecurityView extends GetView<AccountSecurityController> {
  const AccountSecurityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationKeys.accountSecurity.tr)),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _HubSection(
              title: 'Tài khoản'.tr,
              children: [
                _HubTile(
                  icon: Icons.person_outline,
                  title: 'Thông tin tài khoản'.tr,
                  onTap: () => Get.toNamed(AppRouter.accountInformation),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HubSection(
              title: 'Bảo mật'.tr,
              children: [
                _HubTile(
                  icon: Icons.password_outlined,
                  title: 'Đổi mật khẩu'.tr,
                  onTap: () => Get.toNamed(AppRouter.passwordSecurity),
                ),
                const Divider(height: 1),
                _HubTile(
                  icon: Icons.pin_outlined,
                  title: 'Mã PIN bảo vệ tin nhắn'.tr,
                  onTap: () => Get.toNamed(AppRouter.chatPinSecurity),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HubSection(
              title: 'Thiết bị và phiên đăng nhập'.tr,
              children: [
                _HubTile(
                  icon: Icons.devices_outlined,
                  title: 'Thiết bị đã đăng nhập'.tr,
                  onTap: () => Get.toNamed(AppRouter.deviceSessions),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HubSection(
              title: 'Quản lý tài khoản'.tr,
              children: [
                _HubTile(
                  icon: Icons.delete_forever_outlined,
                  iconColor: Theme.of(context).colorScheme.error,
                  title: 'Xóa tài khoản'.tr,
                  titleColor: Theme.of(context).colorScheme.error,
                  onTap: () => Get.toNamed(AppRouter.deleteAccount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HubSection extends StatelessWidget {
  const _HubSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primaryColor;
    return ListTile(
      onTap: onTap,
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
