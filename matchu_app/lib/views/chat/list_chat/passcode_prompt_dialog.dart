import 'package:flutter/material.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:pinput/pinput.dart';

enum PasscodePromptAction { submitted, reset }

class PasscodePromptResult {
  final PasscodePromptAction action;
  final String? passcode;

  const PasscodePromptResult({required this.action, this.passcode});
}

const _passcodeLength = 6;
const _pinBoxSize = 48.0;
const _pinBoxHeightExtra = 8.0;
const _pinSeparatorWidth = 4.0;

class _PasscodeDialogContent extends StatelessWidget {
  final List<Widget> children;

  const _PasscodeDialogContent({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

Widget _buildPasscodeInput({
  required TextEditingController controller,
  required Color primaryColor,
  required TextStyle? textStyle,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final fallbackWidth =
          (_pinBoxSize * _passcodeLength) +
          (_pinSeparatorWidth * (_passcodeLength - 1));
      final maxWidth =
          constraints.maxWidth.isFinite ? constraints.maxWidth : fallbackWidth;
      final totalSeparatorWidth = _pinSeparatorWidth * (_passcodeLength - 1);
      final computedSize = (maxWidth - totalSeparatorWidth) / _passcodeLength;
      final pinBoxSize = computedSize.clamp(36.0, _pinBoxSize).toDouble();
      final pinBoxHeight = pinBoxSize + _pinBoxHeightExtra;
      final baseFontSize = textStyle?.fontSize ?? 24;
      final maxFontSize = pinBoxSize * 0.5;
      final effectiveTextStyle = (textStyle ?? const TextStyle()).copyWith(
        fontSize: baseFontSize > maxFontSize ? maxFontSize : baseFontSize,
        height: 1,
      );

      PinTheme buildPinTheme(Color borderColor) {
        return PinTheme(
          width: pinBoxSize,
          height: pinBoxHeight,
          textStyle: effectiveTextStyle,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        height: pinBoxHeight + 10,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Pinput(
            length: _passcodeLength,
            controller: controller,
            keyboardType: TextInputType.number,
            separatorBuilder: (_) => const SizedBox(width: _pinSeparatorWidth),
            defaultPinTheme: buildPinTheme(primaryColor.withValues(alpha: 0.4)),
            focusedPinTheme: buildPinTheme(primaryColor),
            submittedPinTheme: buildPinTheme(primaryColor),
          ),
        ),
      );
    },
  );
}

Future<String?> showPasscodeSetupDialog(
  BuildContext context, {
  String? title,
  String? description,
  String? confirmTitle,
  String? confirmDescription,
}) {
  final firstController = TextEditingController();
  final secondController = TextEditingController();

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      final color = theme.colorScheme;
      bool confirmStep = false;
      String? errorText;

      return StatefulBuilder(
        builder: (context, setState) {
          final controller = confirmStep ? secondController : firstController;
          final currentTitle =
              confirmStep
                  ? (confirmTitle ?? 'Xác nhận mã PIN')
                  : title ?? 'Thiết lập mã PIN';
          final currentDescription =
              confirmStep
                  ? confirmDescription ?? 'Nhập lại mã PIN để xác nhận'
                  : description ??
                      'Tạo mã PIN để khôi phục tin nhắn trên thiết bị mới';

          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(currentTitle),
              content: _PasscodeDialogContent(
                children: [
                  Text(currentDescription, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  _buildPasscodeInput(
                    controller: controller,
                    primaryColor: color.primary,
                    textStyle: theme.textTheme.headlineSmall,
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
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    firstController.dispose();
    secondController.dispose();
  });
}

Future<PasscodePromptResult?> showPasscodeUnlockDialog(
  BuildContext context, {
  String? errorText,
  String? title,
  String? description,
}) {
  final controller = TextEditingController();

  return showDialog<PasscodePromptResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      final color = theme.colorScheme;
      String? localError = errorText;

      return StatefulBuilder(
        builder: (context, setState) {
          void submitPasscode() {
            final pin = controller.text.trim();
            if (pin.length != 6) {
              setState(() {
                localError = 'Mã PIN phải đủ 6 chữ số';
              });
              return;
            }

            Navigator.of(context).pop(
              PasscodePromptResult(
                action: PasscodePromptAction.submitted,
                passcode: pin,
              ),
            );
          }

          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(title ?? 'Nhập mã PIN'),
              content: _PasscodeDialogContent(
                children: [
                  Text(
                    description ??
                        'Nhập mã PIN để khôi phục tin nhắn cũ trên thiết bị này. '
                            'Nếu quên mã PIN, bạn có thể đặt lại để bắt đầu khóa khôi phục mới.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildPasscodeInput(
                    controller: controller,
                    primaryColor: color.primary,
                    textStyle: theme.textTheme.headlineSmall,
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  const PasscodePromptResult(
                                    action: PasscodePromptAction.reset,
                                  ),
                                );
                              },
                              child: const Text('Đặt lại'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: submitPasscode,
                          child: const Text('Mở khóa'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}

Future<bool> showPasscodeResetConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
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
        ),
      );
    },
  );

  return result ?? false;
}

Future<bool> ensurePasscodeReady(
  BuildContext context, {
  bool allowHistoryLockedBypass = true,
  bool Function()? shouldContinue,
  Future<void> Function()? onPasscodeReset,
  Future<void> Function()? onUnlocked,
  String? setupTitle,
  String? setupDescription,
  String? unlockTitle,
  String? unlockDescription,
}) async {
  bool canContinue() => context.mounted && (shouldContinue?.call() ?? true);

  if (!canContinue()) return false;

  final hasLocal = await PasscodeBackupService.hasLocalBackupKey();
  if (!context.mounted) return false;
  if (hasLocal) return true;
  if (!canContinue()) return false;

  if (allowHistoryLockedBypass) {
    final historyLocked = await PasscodeBackupService.isHistoryLocked();
    if (!context.mounted) return false;
    if (historyLocked) return true;
    if (!canContinue()) return false;
  }

  final hasBackup = await PasscodeBackupService.hasBackupOnServer();
  if (!context.mounted) return false;
  if (!canContinue()) return false;

  if (!hasBackup) {
    final passcode = await showPasscodeSetupDialog(
      context,
      title: setupTitle,
      description: setupDescription,
    );
    if (passcode == null || passcode.isEmpty) return false;
    await PasscodeBackupService.setPasscode(passcode);
    return true;
  }

  String? errorText;
  while (canContinue()) {
    if (!context.mounted) return false;
    if (shouldContinue != null && !shouldContinue()) return false;
    final result = await showPasscodeUnlockDialog(
      context,
      errorText: errorText,
      title: unlockTitle,
      description: unlockDescription,
    );

    if (result == null) return false;

    if (result.action == PasscodePromptAction.reset) {
      if (!context.mounted) return false;
      if (shouldContinue != null && !shouldContinue()) return false;
      final confirm = await showPasscodeResetConfirmDialog(context);
      if (!confirm) continue;

      await PasscodeBackupService.resetPasscode();
      await onPasscodeReset?.call();

      if (!context.mounted) return false;
      if (!canContinue()) return false;
      final newPasscode = await showPasscodeSetupDialog(
        context,
        title: setupTitle,
        description: setupDescription,
      );
      if (newPasscode == null || newPasscode.isEmpty) return false;
      await PasscodeBackupService.setPasscode(newPasscode, lockHistory: true);
      return true;
    }

    final passcode = result.passcode ?? '';
    final unlocked = await PasscodeBackupService.unlockPasscode(passcode);
    if (!unlocked) {
      errorText = 'Mã pin không đúng';
      continue;
    }

    await onUnlocked?.call();
    return true;
  }

  return false;
}
