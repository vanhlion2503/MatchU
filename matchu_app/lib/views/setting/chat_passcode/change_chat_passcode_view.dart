import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/security/chat_passcode_security_controller.dart';
import 'package:matchu_app/views/setting/chat_passcode/widgets/chat_pin_input.dart';

class ChangeChatPasscodeView extends StatefulWidget {
  const ChangeChatPasscodeView({super.key});

  @override
  State<ChangeChatPasscodeView> createState() => _ChangeChatPasscodeViewState();
}

class _ChangeChatPasscodeViewState extends State<ChangeChatPasscodeView> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();

  ChatPasscodeSecurityController get controller =>
      Get.find<ChatPasscodeSecurityController>();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final changed = await controller.changePasscode(
      currentPasscode: _currentController.text,
      newPasscode: _newController.text,
      confirmation: _confirmationController.text,
    );
    if (!changed || !mounted) return;
    Get.back(result: true);
    Get.snackbar(
      'Thành công',
      'Mã PIN đã được thay đổi. Lịch sử tin nhắn được giữ nguyên.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thay đổi mã PIN')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const Text(
            'Khóa khôi phục hiện tại sẽ được mã hóa lại bằng PIN mới. '
            'Tin nhắn và các bản sao lưu khóa không bị xóa.',
          ),
          const SizedBox(height: 24),
          const _PinLabel('Mã PIN hiện tại'),
          const SizedBox(height: 8),
          ChatPinInput(controller: _currentController, autofocus: true),
          const SizedBox(height: 20),
          const _PinLabel('Mã PIN mới'),
          const SizedBox(height: 8),
          ChatPinInput(controller: _newController),
          const SizedBox(height: 20),
          const _PinLabel('Nhập lại mã PIN mới'),
          const SizedBox(height: 8),
          ChatPinInput(controller: _confirmationController),
          const SizedBox(height: 12),
          Obx(
            () =>
                controller.errorMessage.value.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                      controller.errorMessage.value,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => FilledButton(
              onPressed: controller.isActionRunning.value ? null : _submit,
              child:
                  controller.isActionRunning.value
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Cập nhật mã PIN'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinLabel extends StatelessWidget {
  const _PinLabel(this.text);

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
