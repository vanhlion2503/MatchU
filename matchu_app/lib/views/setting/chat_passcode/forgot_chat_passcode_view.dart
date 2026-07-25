import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/security/chat_passcode_security_controller.dart';
import 'package:matchu_app/routes/app_router.dart';

class ForgotChatPasscodeView extends GetView<ChatPasscodeSecurityController> {
  const ForgotChatPasscodeView({super.key});

  Future<void> _openMethod(String route) async {
    // GetPages in this project use dynamic named routes. Adding <bool> here
    // makes GetX cast GetPageRoute<dynamic> to Route<bool?> and crashes.
    final completed = await Get.toNamed(route);
    if (completed == true) {
      Get.back(result: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên hoặc đặt lại mã PIN')),
      body: Obx(() {
        final status = controller.status.value;
        if (controller.isLoading.value && status == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (status == null) {
          return _LoadError(
            message: controller.errorMessage.value,
            onRetry: controller.loadStatus,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _RecoveryOptionCard(
              icon: Icons.face_retouching_natural,
              title: 'Khôi phục và giữ lịch sử',
              description:
                  'Xác thực khuôn mặt đã đăng ký, sau đó tạo mã PIN mới. '
                  'Khóa khôi phục và lịch sử tin nhắn được giữ nguyên.',
              actionLabel: 'Khôi phục bằng khuôn mặt',
              enabled: status.canRecoverWithFace,
              unavailableMessage:
                  status.isFaceVerified
                      ? 'Chưa có bản sao khôi phục khuôn mặt phù hợp.'
                      : 'Tài khoản chưa thiết lập xác thực khuôn mặt.',
              onTap: () => _openMethod(AppRouter.recoverChatPin),
            ),
            const SizedBox(height: 16),
            _RecoveryOptionCard(
              icon: Icons.lock_reset_outlined,
              title: 'Đặt lại không thể khôi phục',
              description:
                  'Tạo khóa khôi phục hoàn toàn mới. Bản sao khóa cũ sẽ bị '
                  'xóa và lịch sử cũ có thể không khôi phục được trên thiết bị mới.',
              actionLabel: 'Tiếp tục đặt lại',
              isDestructive: true,
              onTap: () => _openMethod(AppRouter.resetChatPin),
            ),
          ],
        );
      }),
    );
  }
}

class _RecoveryOptionCard extends StatelessWidget {
  const _RecoveryOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
    this.enabled = true,
    this.isDestructive = false,
    this.unavailableMessage,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;
  final bool enabled;
  final bool isDestructive;
  final String? unavailableMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = isDestructive ? colors.error : colors.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (!enabled && unavailableMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  unavailableMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        color: enabled ? accent : colors.outline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: enabled ? accent : colors.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

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
            Text(
              message.isEmpty
                  ? 'Không thể tải trạng thái khôi phục mã PIN.'
                  : message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
