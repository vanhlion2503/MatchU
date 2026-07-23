import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

class FaceTemplateUpdatePinScreen extends StatefulWidget {
  const FaceTemplateUpdatePinScreen({
    super.key,
    required this.errorText,
    required this.isSubmitting,
    required this.onConfirm,
    required this.onCancel,
  });

  final String errorText;
  final bool isSubmitting;
  final Future<bool> Function(String passcode) onConfirm;
  final VoidCallback onCancel;

  @override
  State<FaceTemplateUpdatePinScreen> createState() =>
      _FaceTemplateUpdatePinScreenState();
}

class _FaceTemplateUpdatePinScreenState
    extends State<FaceTemplateUpdatePinScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _localError = "";

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final passcode = _pinController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(passcode)) {
      setState(() => _localError = "Mã PIN phải gồm đúng 6 chữ số.");
      return;
    }
    setState(() => _localError = "");
    final accepted = await widget.onConfirm(passcode);
    if (!accepted && mounted) {
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final error = _localError.isNotEmpty ? _localError : widget.errorText;
    final pinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.isSubmitting ? null : widget.onCancel,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 34,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                "Xác nhận mã PIN chat",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Nhập mã PIN 6 số đang dùng để bảo vệ và khôi phục tin nhắn. "
                "Mã PIN đúng sẽ cho phép cập nhật dữ liệu khuôn mặt.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              Pinput(
                length: 6,
                controller: _pinController,
                autofocus: true,
                obscureText: true,
                enabled: !widget.isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                defaultPinTheme: pinTheme,
                focusedPinTheme: pinTheme.copyDecorationWith(
                  border: Border.all(color: colors.primary, width: 2),
                ),
                errorPinTheme: pinTheme.copyDecorationWith(
                  border: Border.all(color: colors.error, width: 1.8),
                ),
                forceErrorState: error.isNotEmpty,
                onChanged: (_) {
                  if (_localError.isNotEmpty) {
                    setState(() => _localError = "");
                  }
                },
                onCompleted: (_) => _confirm(),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child:
                    error.isEmpty
                        ? const SizedBox(height: 36)
                        : Padding(
                          key: ValueKey(error),
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.isSubmitting ? null : _confirm,
                  child:
                      widget.isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("Xác nhận mã PIN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
