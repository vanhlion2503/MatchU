import 'dart:math' as math;

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
const _dialogInsetHorizontal = 40.0;
const _dialogContentHorizontalPadding = 24.0;

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
  Color? errorColor,
  bool readOnly = false,
  bool hasError = false,
  int shakeTrigger = 0,
  ValueChanged<String>? onChanged,
}) {
  return Builder(
    builder: (context) {
      final fallbackWidth =
          (_pinBoxSize * _passcodeLength) +
          (_pinSeparatorWidth * (_passcodeLength - 1));
      final totalSeparatorWidth = _pinSeparatorWidth * (_passcodeLength - 1);
      final screenWidth = MediaQuery.sizeOf(context).width;
      final estimatedMaxWidth =
          screenWidth -
          (_dialogInsetHorizontal * 2) -
          (_dialogContentHorizontalPadding * 2);
      final maxWidth =
          estimatedMaxWidth.isFinite && estimatedMaxWidth > 0
              ? math.min(estimatedMaxWidth, fallbackWidth)
              : fallbackWidth;
      final computedSize = (maxWidth - totalSeparatorWidth) / _passcodeLength;
      final pinBoxSize = computedSize.clamp(12.0, _pinBoxSize).toDouble();
      final pinBoxHeight = pinBoxSize + _pinBoxHeightExtra;
      final inputWidth = (pinBoxSize * _passcodeLength) + totalSeparatorWidth;
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

      final effectiveErrorColor = errorColor ?? primaryColor;
      final pinput = Pinput(
        length: _passcodeLength,
        controller: controller,
        readOnly: readOnly,
        onChanged: onChanged,
        forceErrorState: hasError,
        errorPinTheme: buildPinTheme(effectiveErrorColor),
        keyboardType: TextInputType.number,
        separatorBuilder: (_) => const SizedBox(width: _pinSeparatorWidth),
        defaultPinTheme: buildPinTheme(primaryColor.withValues(alpha: 0.4)),
        focusedPinTheme: buildPinTheme(primaryColor),
        submittedPinTheme: buildPinTheme(primaryColor),
      );

      final input =
          shakeTrigger <= 0
              ? pinput
              : TweenAnimationBuilder<double>(
                key: ValueKey(shakeTrigger),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                child: pinput,
                builder: (context, value, child) {
                  final dx = math.sin(value * math.pi * 8) * (1 - value) * 8;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
              );

      return SizedBox(
        width: inputWidth,
        height: pinBoxHeight + 10,
        child: Align(alignment: Alignment.centerLeft, child: input),
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
  Future<bool> Function(String passcode)? onUnlock,
}) {
  final controller = TextEditingController();

  return showDialog<PasscodePromptResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      final color = theme.colorScheme;
      String? localError = errorText;
      bool isSubmitting = false;
      int shakeTrigger = 0;

      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submitPasscode() async {
            if (isSubmitting) return;

            final pin = controller.text.trim();
            if (pin.length != 6) {
              setState(() {
                shakeTrigger++;
                localError = 'Mã PIN phải đủ 6 chữ số';
              });
              return;
            }

            if (onUnlock == null) {
              Navigator.of(context).pop(
                PasscodePromptResult(
                  action: PasscodePromptAction.submitted,
                  passcode: pin,
                ),
              );
              return;
            }

            setState(() {
              isSubmitting = true;
              localError = null;
            });

            try {
              final unlocked = await onUnlock(pin);
              if (!context.mounted) return;

              if (unlocked) {
                Navigator.of(context).pop(
                  PasscodePromptResult(
                    action: PasscodePromptAction.submitted,
                    passcode: pin,
                  ),
                );
                return;
              }

              setState(() {
                isSubmitting = false;
                shakeTrigger++;
                localError = 'Bạn đã nhập sai mã PIN, vui lòng nhập lại';
                controller.clear();
              });
            } catch (_) {
              if (!context.mounted) return;

              setState(() {
                isSubmitting = false;
                localError = 'Không thể kiểm tra mã PIN. Vui lòng thử lại.';
              });
            }
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
                    errorColor: color.error,
                    readOnly: isSubmitting,
                    hasError: localError != null,
                    shakeTrigger: shakeTrigger,
                    onChanged: (_) {
                      if (localError == null) return;
                      setState(() {
                        localError = null;
                      });
                    },
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
                              onPressed:
                                  isSubmitting
                                      ? null
                                      : () {
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
                          onPressed: isSubmitting ? null : submitPasscode,
                          child:
                              isSubmitting
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Mở khóa'),
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

  while (canContinue()) {
    if (!context.mounted) return false;
    if (shouldContinue != null && !shouldContinue()) return false;
    final result = await showPasscodeUnlockDialog(
      context,
      title: unlockTitle,
      description: unlockDescription,
      onUnlock: PasscodeBackupService.unlockPasscode,
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

    await onUnlocked?.call();
    return true;
  }

  return false;
}
