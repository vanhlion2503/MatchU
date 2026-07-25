import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/security/chat_passcode_security_controller.dart';
import 'package:matchu_app/views/setting/chat_passcode/widgets/chat_pin_input.dart';

class ForgotChatPasscodeView extends StatefulWidget {
  const ForgotChatPasscodeView({super.key});

  @override
  State<ForgotChatPasscodeView> createState() => _ForgotChatPasscodeViewState();
}

class _ForgotChatPasscodeViewState extends State<ForgotChatPasscodeView> {
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  ChatPasscodeSecurityController get controller =>
      Get.find<ChatPasscodeSecurityController>();

  @override
  void dispose() {
    _newController.dispose();
    _confirmationController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _recoverWithFace() async {
    final recovered = await controller.recoverWithFace(
      newPasscode: _newController.text,
      confirmation: _confirmationController.text,
    );
    if (!recovered || !mounted) return;
    Get.back(result: true);
    Get.snackbar(
      'Khôi phục thành công',
      'PIN mới đã được thiết lập và lịch sử tin nhắn được giữ nguyên.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _startDestructiveReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Đặt lại khóa khôi phục?'),
            content: const Text(
              'Bản sao khóa khôi phục cũ sẽ bị xóa vĩnh viễn. Những thiết bị đã '
              'có khóa cũ vẫn có thể giữ tin nhắn trên chính thiết bị đó, nhưng '
              'lịch sử cũ không còn được đảm bảo khôi phục trên thiết bị mới.',
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
      _finishReset();
    }
  }

  Future<void> _completeMfa() async {
    final completed = await controller.completeMfaReset(_otpController.text);
    if (completed && mounted) _finishReset();
  }

  void _finishReset() {
    Get.back(result: true);
    Get.snackbar(
      'Đã đặt lại mã PIN',
      'Khóa khôi phục mới đã được tạo.',
      snackPosition: SnackPosition.BOTTOM,
    );
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Trước tiên, hãy chọn PIN mới. Nếu có bản sao khôi phục khuôn '
              'mặt, bạn có thể giữ lại toàn bộ lịch sử.',
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Mã PIN mới'),
            const SizedBox(height: 8),
            ChatPinInput(
              controller: _newController,
              enabled: !controller.isActionRunning.value,
            ),
            const SizedBox(height: 18),
            const _SectionLabel('Nhập lại mã PIN mới'),
            const SizedBox(height: 8),
            ChatPinInput(
              controller: _confirmationController,
              enabled: !controller.isActionRunning.value,
            ),
            if (status?.canRecoverWithFace == true) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Khôi phục và giữ lịch sử',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Xác thực khuôn mặt để lấy lại khóa khôi phục hiện tại.',
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed:
                            controller.isActionRunning.value
                                ? null
                                : _recoverWithFace,
                        icon: const Icon(Icons.face_retouching_natural),
                        label: const Text('Khôi phục bằng khuôn mặt'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Đặt lại không thể khôi phục',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chỉ sử dụng khi bạn không thể xác thực bằng PIN cũ hoặc khuôn mặt.',
                    ),
                    if (controller.hasPasswordProvider) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        enabled: !controller.isActionRunning.value,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu tài khoản hiện tại',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Bạn sẽ được yêu cầu xác thực lại tài khoản Google.',
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed:
                          controller.isActionRunning.value
                              ? null
                              : _startDestructiveReset,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Xác thực và đặt lại PIN'),
                    ),
                  ],
                ),
              ),
            ),
            if (controller.isMfaPending.value) ...[
              const SizedBox(height: 20),
              Card(
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
                      Text('Nhập mã đã gửi đến ${controller.mfaPhoneNumber}.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpController,
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
                        onPressed:
                            controller.isActionRunning.value
                                ? null
                                : _completeMfa,
                        child: const Text('Xác nhận và đặt lại'),
                      ),
                      TextButton(
                        onPressed:
                            controller.isActionRunning.value
                                ? null
                                : controller.cancelPendingMfa,
                        child: const Text('Hủy xác thực OTP'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (controller.errorMessage.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                controller.errorMessage.value,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (controller.isActionRunning.value) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

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
