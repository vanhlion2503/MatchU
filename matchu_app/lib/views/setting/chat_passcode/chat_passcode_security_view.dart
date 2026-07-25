import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/security/chat_passcode_security_controller.dart';
import 'package:matchu_app/routes/app_router.dart';

class ChatPasscodeSecurityView extends GetView<ChatPasscodeSecurityController> {
  const ChatPasscodeSecurityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mã PIN bảo vệ tin nhắn')),
      body: Obx(() {
        if (controller.isLoading.value && controller.status.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty &&
            controller.status.value == null) {
          return _ErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.loadStatus,
          );
        }

        final status = controller.status.value;
        if (status == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: controller.loadStatus,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      enabled: status.isConfigured,
                      minTileHeight: 72,
                      leading: const Icon(Icons.password_outlined),
                      title: const Text('Thay đổi mã PIN'),
                      subtitle: const Text(
                        'Đổi PIN nhưng vẫn giữ nguyên lịch sử tin nhắn.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.toNamed(AppRouter.changeChatPin),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled: status.isConfigured,
                      minTileHeight: 72,
                      leading: const Icon(Icons.lock_reset_outlined),
                      title: const Text('Quên hoặc đặt lại mã PIN'),
                      subtitle: const Text(
                        'Chọn khôi phục lịch sử hoặc tạo khóa khôi phục mới.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.toNamed(AppRouter.forgotChatPin),
                    ),
                  ],
                ),
              ),
              if (!status.isConfigured) ...[
                const SizedBox(height: 16),
                const _InfoCard(
                  icon: Icons.info_outline,
                  text:
                      'PIN sẽ được yêu cầu khi tính năng chat mã hóa tạo '
                      'khóa khôi phục lần đầu.',
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
