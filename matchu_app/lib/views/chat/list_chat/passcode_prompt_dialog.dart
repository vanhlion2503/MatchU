import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

enum PasscodePromptAction { submitted, skipped, reset }

class PasscodePromptResult {
  final PasscodePromptAction action;
  final String? passcode;

  const PasscodePromptResult({
    required this.action,
    this.passcode,
  });
}

Future<String?> showPasscodeSetupDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      final color = theme.colorScheme;
      final firstController = TextEditingController();
      final secondController = TextEditingController();
      bool confirmStep = false;
      String? errorText;

      PinTheme buildPinTheme(Color borderColor) {
        return PinTheme(
          width: 48,
          height: 48,
          textStyle: theme.textTheme.headlineSmall,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
        );
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final controller = confirmStep ? secondController : firstController;
          final title =
              confirmStep ? 'Xác nhận mã PIN' : 'Thiết lập mã PIN';
          final description = confirmStep
              ? 'Nhập lại mã PIN để xác nhận'
              : 'Tạo mã PIN để khôi phục tin nhắn trên thiết bị mới';

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Pinput(
                  length: 6,
                  controller: controller,
                  keyboardType: TextInputType.number,
                  defaultPinTheme:
                      buildPinTheme(color.primary.withOpacity(0.4)),
                  focusedPinTheme: buildPinTheme(color.primary),
                  submittedPinTheme: buildPinTheme(color.primary),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (confirmStep)
                TextButton(
                  onPressed: () {
                    setState(() {
                      confirmStep = false;
                      secondController.clear();
                      errorText = null;
                    });
                  },
                  child: const Text('Quay lại'),
                ),
              ElevatedButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (pin.length != 6) {
                    setState(() {
                      errorText = 'Mã PIN phải đủ 6 số';
                    });
                    return;
                  }

                  if (!confirmStep) {
                    setState(() {
                      confirmStep = true;
                      errorText = null;
                      secondController.clear();
                    });
                    return;
                  }

                  if (pin != firstController.text.trim()) {
                    setState(() {
                      errorText = 'Mã PIN không khớp';
                    });
                    return;
                  }

                  Navigator.of(context).pop(pin);
                },
                child: Text(confirmStep ? 'Xác nhận' : 'Tiếp tục'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<PasscodePromptResult?> showPasscodeUnlockDialog(
  BuildContext context, {
  String? errorText,
}) {
  return showDialog<PasscodePromptResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      final color = theme.colorScheme;
      final controller = TextEditingController();
      String? localError = errorText;

      PinTheme buildPinTheme(Color borderColor) {
        return PinTheme(
          width: 48,
          height: 48,
          textStyle: theme.textTheme.headlineSmall,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
        );
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nhap ma PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhập mã PIN để khôi phục tin nhắn cũ trên thiết bị này. '
                  'Nếu không có mã PIN bạn vẫn có thể chat nhưng không có lịch sử',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Pinput(
                  length: 6,
                  controller: controller,
                  keyboardType: TextInputType.number,
                  defaultPinTheme:
                      buildPinTheme(color.primary.withOpacity(0.4)),
                  focusedPinTheme: buildPinTheme(color.primary),
                  submittedPinTheme: buildPinTheme(color.primary),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    localError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(const PasscodePromptResult(
                    action: PasscodePromptAction.skipped,
                  ));
                },
                child: const Text('Tiếp tục (Không xem lại lịch sửa)'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(const PasscodePromptResult(
                    action: PasscodePromptAction.reset,
                  ));
                },
                child: const Text('Quên mã? Đặt lại'),
              ),
              ElevatedButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (pin.length != 6) {
                    setState(() {
                      localError = 'Mã PIN phải đủ 6 chữ số';
                    });
                    return;
                  }

                  Navigator.of(context).pop(PasscodePromptResult(
                    action: PasscodePromptAction.submitted,
                    passcode: pin,
                  ));
                },
                child: const Text('Mở khóa'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showPasscodeResetConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Đặt lại mã PIN'),
        content: const Text(
          'Việc nãy sẽ xóa toàn bộ tin nhắn đã mã hóa cũ trên thiết bị này',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đặt lại'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
