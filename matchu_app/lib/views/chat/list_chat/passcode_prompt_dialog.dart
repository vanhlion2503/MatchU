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
              confirmStep ? 'Xac nhan ma PIN' : 'Thiet lap ma PIN';
          final description = confirmStep
              ? 'Nhap lai ma PIN de xac nhan.'
              : 'Tao ma PIN de khoi phuc tin nhan tren thiet bi moi.';

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
                  child: const Text('Quay lai'),
                ),
              ElevatedButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (pin.length != 6) {
                    setState(() {
                      errorText = 'Ma PIN phai du 6 chu so';
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
                      errorText = 'Ma PIN khong khop';
                    });
                    return;
                  }

                  Navigator.of(context).pop(pin);
                },
                child: Text(confirmStep ? 'Xac nhan' : 'Tiep tuc'),
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
                  'Nhap ma PIN de khoi phuc tin nhan cu tren thiet bi nay. '
                  'Neu khong co ma PIN, ban van co the chat nhung khong xem lich su.',
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
                child: const Text('Tiep tuc (khong xem lich su)'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(const PasscodePromptResult(
                    action: PasscodePromptAction.reset,
                  ));
                },
                child: const Text('Quen ma? Dat lai'),
              ),
              ElevatedButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (pin.length != 6) {
                    setState(() {
                      localError = 'Ma PIN phai du 6 chu so';
                    });
                    return;
                  }

                  Navigator.of(context).pop(PasscodePromptResult(
                    action: PasscodePromptAction.submitted,
                    passcode: pin,
                  ));
                },
                child: const Text('Mo khoa'),
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
        title: const Text('Dat lai ma PIN?'),
        content: const Text(
          'Viec nay se xoa toan bo tin nhan da ma hoa cu tren thiet bi nay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dat lai'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
