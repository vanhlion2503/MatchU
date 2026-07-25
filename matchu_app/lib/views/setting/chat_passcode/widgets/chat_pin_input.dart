import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

class ChatPinInput extends StatelessWidget {
  const ChatPinInput({
    required this.controller,
    super.key,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = true,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = PinTheme(
      width: 48,
      height: 56,
      textStyle: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 1.4),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 324.0;
        final width =
            ((available - spacing * 5) / 6).clamp(32.0, 48.0).toDouble();
        final responsiveTheme = theme.copyWith(width: width);

        return Pinput(
          length: 6,
          controller: controller,
          autofocus: autofocus,
          enabled: enabled,
          obscureText: obscureText,
          obscuringCharacter: '●',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          separatorBuilder: (_) => const SizedBox(width: spacing),
          defaultPinTheme: responsiveTheme,
          focusedPinTheme: responsiveTheme.copyDecorationWith(
            border: Border.all(color: colors.primary, width: 2),
          ),
          submittedPinTheme: responsiveTheme.copyDecorationWith(
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}
