import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/security/chat_passcode_security_controller.dart';
import 'package:matchu_app/views/setting/chat_passcode/widgets/chat_pin_input.dart';

enum ChatPasscodeRecoveryMode { faceRecovery, destructiveReset }

class NewChatPasscodeView extends StatefulWidget {
  const NewChatPasscodeView({required this.mode, super.key});

  final ChatPasscodeRecoveryMode mode;

  @override
  State<NewChatPasscodeView> createState() => _NewChatPasscodeViewState();
}

class _NewChatPasscodeViewState extends State<NewChatPasscodeView> {
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  ChatPasscodeSecurityController get controller =>
      Get.find<ChatPasscodeSecurityController>();

  bool get isFaceRecovery =>
      widget.mode == ChatPasscodeRecoveryMode.faceRecovery;

  @override
  void initState() {
    super.initState();
    controller.cancelPendingMfa();
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmationController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitFaceRecovery() async {
    final recovered = await controller.recoverWithFace(
      newPasscode: _newController.text,
      confirmation: _confirmationController.text,
    );
    if (!recovered || !mounted) return;
    _finish(
      title: 'Khôi phục thành công',
      message: 'PIN mới đã được thiết lập và lịch sử được giữ nguyên.',
    );
  }

  Future<void> _submitDestructiveReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Tạo khóa khôi phục mới?'),
            content: const Text(
              'Bản sao khóa khôi phục cũ sẽ bị xóa vĩnh viễn. Lịch sử cũ '
              'có thể không khôi phục được trên thiết bị mới.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Tôi hiểu, tiếp tục'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final result = await controller.startDestructiveReset(
      currentPassword: _passwordController.text,
      newPasscode: _newController.text,
      confirmation: _confirmationController.text,
    );
    if (!mounted) return;
    if (result == DestructiveResetResult.completed) {
      _finish(
        title: 'Đã đặt lại mã PIN',
        message: 'Khóa khôi phục mới đã được tạo.',
      );
    }
  }

  Future<void> _completeMfa() async {
    final completed = await controller.completeMfaReset(_otpController.text);
    if (!completed || !mounted) return;
    _finish(
      title: 'Đã đặt lại mã PIN',
      message: 'Khóa khôi phục mới đã được tạo.',
    );
  }

  void _finish({required String title, required String message}) {
    Get.back(result: true);
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = isFaceRecovery ? colors.primary : colors.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFaceRecovery ? 'Khôi phục mã PIN' : 'Đặt lại mã PIN'),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _MethodHeader(
              icon:
                  isFaceRecovery
                      ? Icons.face_retouching_natural
                      : Icons.lock_reset_outlined,
              color: accent,
              title:
                  isFaceRecovery
                      ? 'Tạo PIN mới và giữ lịch sử'
                      : 'Tạo PIN và khóa khôi phục mới',
              description:
                  isFaceRecovery
                      ? 'Sau khi nhập PIN mới, bạn sẽ quét khuôn mặt để '
                          'khôi phục khóa giải mã hiện tại.'
                      : 'Bạn cần xác thực lại tài khoản trước khi khóa cũ '
                          'được thay thế bằng khóa khôi phục mới.',
            ),
            const SizedBox(height: 28),
            const _FieldLabel('Mã PIN mới'),
            const SizedBox(height: 8),
            ChatPinInput(
              controller: _newController,
              autofocus: true,
              enabled: !controller.isActionRunning.value,
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Nhập lại mã PIN mới'),
            const SizedBox(height: 8),
            ChatPinInput(
              controller: _confirmationController,
              enabled: !controller.isActionRunning.value,
            ),
            if (!isFaceRecovery) ...[
              const SizedBox(height: 24),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: 20),
              const _FieldLabel('Xác thực tài khoản'),
              const SizedBox(height: 8),
              if (controller.hasPasswordProvider)
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !controller.isActionRunning.value,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu tài khoản hiện tại',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.account_circle_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bạn sẽ được yêu cầu xác thực lại tài khoản Google.',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: colors.onErrorContainer),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Thao tác này không khôi phục khóa lịch sử cũ. '
                        'Chỉ tiếp tục khi bạn không thể dùng PIN cũ hoặc khuôn mặt.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (controller.errorMessage.value.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                controller.errorMessage.value,
                style: TextStyle(color: colors.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  controller.isActionRunning.value
                      ? null
                      : isFaceRecovery
                      ? _submitFaceRecovery
                      : _submitDestructiveReset,
              style:
                  isFaceRecovery
                      ? null
                      : FilledButton.styleFrom(backgroundColor: colors.error),
              icon:
                  controller.isActionRunning.value
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                        isFaceRecovery
                            ? Icons.face_retouching_natural
                            : Icons.lock_reset_outlined,
                      ),
              label: Text(
                isFaceRecovery
                    ? 'Quét khuôn mặt và lưu PIN'
                    : 'Xác thực và đặt lại PIN',
              ),
            ),
            if (!isFaceRecovery && controller.isMfaPending.value) ...[
              const SizedBox(height: 20),
              _MfaCard(
                phoneNumber: controller.mfaPhoneNumber,
                otpController: _otpController,
                isRunning: controller.isActionRunning.value,
                onConfirm: _completeMfa,
                onCancel: controller.cancelPendingMfa,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodHeader extends StatelessWidget {
  const _MethodHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _MfaCard extends StatelessWidget {
  const _MfaCard({
    required this.phoneNumber,
    required this.otpController,
    required this.isRunning,
    required this.onConfirm,
    required this.onCancel,
  });

  final String phoneNumber;
  final TextEditingController otpController;
  final bool isRunning;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Xác nhận OTP',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('Nhập mã đã gửi đến $phoneNumber.'),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Mã OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isRunning ? null : onConfirm,
              child: const Text('Xác nhận và đặt lại'),
            ),
            TextButton(
              onPressed: isRunning ? null : onCancel,
              child: const Text('Hủy xác thực OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
