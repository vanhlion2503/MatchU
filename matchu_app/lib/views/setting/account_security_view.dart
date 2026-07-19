import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:matchu_app/controllers/user/account_security_controller.dart';
import 'package:matchu_app/models/account_security/account_security_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/utils/otp_phone_formatter.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

enum AccountSecurityDetailSection { account, password, devices, deleteAccount }

/// Màn hình chi tiết dùng chung để giữ toàn bộ luồng xác thực ở một nơi.
/// Mỗi route chỉ truyền vào một nhóm chức năng cần hiển thị.
class AccountSecurityDetailView extends GetView<AccountSecurityController> {
  const AccountSecurityDetailView({required this.section, super.key});

  final AccountSecurityDetailSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: Obx(() {
        if (controller.isLoading.value && controller.account.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.account.value == null) {
          return _ErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.load,
          );
        }

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [_selectedSection(context)],
              ),
            ),
            if (controller.isActionRunning.value)
              const Positioned.fill(child: _BlockingProgress()),
          ],
        );
      }),
    );
  }

  String get _pageTitle => switch (section) {
    AccountSecurityDetailSection.account => 'Thông tin tài khoản'.tr,
    AccountSecurityDetailSection.password => 'Đổi mật khẩu'.tr,
    AccountSecurityDetailSection.devices => 'Thiết bị và phiên đăng nhập'.tr,
    AccountSecurityDetailSection.deleteAccount => 'Xóa tài khoản'.tr,
  };

  Widget _selectedSection(BuildContext context) => switch (section) {
    AccountSecurityDetailSection.account => _accountSection(
      context,
      controller.account.value!,
    ),
    AccountSecurityDetailSection.password => _securitySection(context),
    AccountSecurityDetailSection.devices => _deviceSection(context),
    AccountSecurityDetailSection.deleteAccount => _accountManagementSection(
      context,
    ),
  };

  Widget _accountSection(BuildContext context, AccountSecurityInfo account) {
    final providers = account.providerLabels.join(', ');
    return _SecuritySection(
      title: 'Tài khoản'.tr,
      children: [
        _SecurityTile(
          icon: Icons.email_outlined,
          title: 'Email'.tr,
          subtitle: account.email,
          trailingLabel:
              account.hasPasswordProvider
                  ? (account.emailVerified
                      ? 'Đã xác minh'.tr
                      : 'Chưa xác minh'.tr)
                  : 'Google quản lý'.tr,
          trailingColor:
              !account.hasPasswordProvider
                  ? Theme.of(context).hintColor
                  : account.emailVerified
                  ? AppTheme.successColor
                  : Theme.of(context).colorScheme.error,
          onTap:
              account.hasPasswordProvider ? () => _changeEmail(context) : null,
        ),
        _SecurityTile(
          icon: Icons.phone_outlined,
          title: 'Số điện thoại'.tr,
          subtitle:
              account.maskedPhoneNumber.isEmpty
                  ? 'Chưa có số điện thoại'.tr
                  : account.maskedPhoneNumber,
          trailingLabel: 'Thay đổi'.tr,
          onTap: () => _changePhoneNumber(context),
        ),
        _SecurityTile(
          icon: Icons.key_outlined,
          title: 'Phương thức đăng nhập'.tr,
          subtitle: providers.isEmpty ? 'Không xác định'.tr : providers,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _securitySection(BuildContext context) {
    return _SecuritySection(
      title: 'Bảo mật'.tr,
      children: [
        _SecurityTile(
          icon: Icons.password_outlined,
          title: 'Đổi mật khẩu'.tr,
          subtitle:
              controller.canChangePassword
                  ? 'Cập nhật mật khẩu đăng nhập của bạn'.tr
                  : 'Tài khoản này đăng nhập bằng Google'.tr,
          trailingLabel: controller.canChangePassword ? 'Thay đổi'.tr : null,
          onTap:
              controller.canChangePassword
                  ? () => _changePassword(context)
                  : null,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _deviceSection(BuildContext context) {
    final devices = controller.devices;
    return _SecuritySection(
      title: 'Thiết bị và phiên đăng nhập'.tr,
      children: [
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Chưa tìm thấy thông tin thiết bị.'.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...devices.indexed.map((entry) {
            final index = entry.$1;
            final device = entry.$2;
            return _DeviceTile(
              device: device,
              showDivider: index != devices.length - 1,
            );
          }),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () => _signOutAllDevices(context),
            icon: const Icon(Icons.logout),
            label: Text('Đăng xuất khỏi tất cả thiết bị'.tr),
          ),
        ),
      ],
    );
  }

  Widget _accountManagementSection(BuildContext context) {
    final dangerColor = Theme.of(context).colorScheme.error;
    return _SecuritySection(
      title: 'Quản lý tài khoản'.tr,
      children: [
        _SecurityTile(
          icon: Icons.delete_forever_outlined,
          iconColor: dangerColor,
          title: 'Xóa tài khoản'.tr,
          titleColor: dangerColor,
          subtitle: 'Xóa vĩnh viễn tài khoản và dữ liệu cá nhân'.tr,
          trailingLabel: 'Xóa'.tr,
          trailingColor: dangerColor,
          onTap: () => _deleteAccount(context),
          showDivider: false,
        ),
      ],
    );
  }

  Future<void> _changeEmail(BuildContext context) async {
    final input = await _showEmailDialog(context);
    if (input == null) return;
    if (!context.mounted) return;

    try {
      if (!await _reauthenticate(context, password: input.password)) return;
      await controller.requestEmailChange(input.email);
      if (!context.mounted) return;
      final completed = await _showEmailVerificationPendingDialog(
        context,
        newEmail: input.email,
      );
      if (completed) {
        _showSuccess('Email đã được thay đổi thành công.'.tr);
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _showEmailVerificationPendingDialog(
    BuildContext context, {
    required String newEmail,
  }) async {
    var isChecking = false;
    String? statusMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setState) {
              final theme = Theme.of(context);
              final colors = theme.colorScheme;

              Future<void> openInbox() async {
                final gmailUri = Uri.https('mail.google.com', '/mail/u/', {
                  'authuser': newEmail,
                });
                try {
                  final opened = await launchUrl(
                    gmailUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (opened || !dialogContext.mounted) return;
                } catch (_) {
                  if (!dialogContext.mounted) return;
                }
                setState(
                  () =>
                      statusMessage =
                          'Không thể mở Gmail. Vui lòng mở hộp thư thủ công.'
                              .tr,
                );
              }

              Future<void> completeChange() async {
                if (isChecking) return;
                setState(() {
                  isChecking = true;
                  statusMessage = null;
                });

                await controller.load();
                if (!dialogContext.mounted) return;

                final currentEmail =
                    controller.account.value?.email.trim().toLowerCase() ?? '';
                if (currentEmail == newEmail.trim().toLowerCase()) {
                  Navigator.pop(dialogContext, true);
                  return;
                }

                setState(() {
                  isChecking = false;
                  statusMessage =
                      controller.errorMessage.isNotEmpty
                          ? controller.errorMessage.value
                          : 'Email mới chưa được xác minh. Hãy bấm liên kết trong hộp thư rồi thử lại.'
                              .tr;
                });
              }

              return PopScope(
                canPop: false,
                child: AlertDialog(
                  constraints: const BoxConstraints(maxWidth: 420),
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  title: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          color: colors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Xác minh email mới'.tr,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Liên kết xác minh đã được gửi đến'.tr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            newEmail,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _EmailVerificationStep(
                          number: 1,
                          text: 'Mở Gmail hoặc hộp thư của email mới.'.tr,
                        ),
                        const SizedBox(height: 12),
                        _EmailVerificationStep(
                          number: 2,
                          text: 'Bấm vào liên kết xác minh do MatchU gửi.'.tr,
                        ),
                        const SizedBox(height: 12),
                        _EmailVerificationStep(
                          number: 3,
                          text:
                              'Quay lại ứng dụng và chọn Hoàn tất thay đổi.'.tr,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isChecking ? null : openInbox,
                            icon: const Icon(Icons.open_in_new),
                            label: Text('Mở Gmail'.tr),
                          ),
                        ),
                        if (statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.errorContainer.withValues(
                                alpha: 0.45,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusMessage!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'Hủy bỏ chỉ đóng bước này. Để giữ email hiện tại, không mở liên kết đã gửi.'
                              .tr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  actions: [
                    TextButton(
                      onPressed:
                          isChecking
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                      child: Text('Hủy bỏ'.tr),
                    ),
                    FilledButton(
                      onPressed: isChecking ? null : completeChange,
                      child:
                          isChecking
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text('Hoàn tất thay đổi'.tr),
                    ),
                  ],
                ),
              );
            },
          ),
    );

    return result ?? false;
  }

  Future<void> _changePassword(BuildContext context) async {
    final input = await _showPasswordDialog(context);
    if (input == null) return;
    if (!context.mounted) return;

    try {
      if (!await _reauthenticate(context, password: input.currentPassword)) {
        return;
      }
      await controller.changePassword(input.newPassword);
      _showSuccess('Mật khẩu đã được thay đổi.'.tr);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _changePhoneNumber(BuildContext context) async {
    final input = await _showPhoneDialog(context);
    if (input == null) return;
    if (!context.mounted) return;
    final currentPhone = controller.account.value?.phoneNumber.trim() ?? '';
    if (input.phoneNumber == currentPhone) {
      _showErrorMessage('Số điện thoại mới phải khác số hiện tại.'.tr);
      return;
    }

    try {
      if (!await _reauthenticate(context, password: input.password)) return;
      final challenge = await controller.startPhoneChange(input.phoneNumber);
      if (!context.mounted) return;
      final smsCode =
          challenge.credential != null
              ? ''
              : await _showOtpDialog(
                context,
                phoneNumber: challenge.phoneNumber,
              );
      if (smsCode == null) return;
      await controller.completePhoneChange(
        challenge: challenge,
        smsCode: smsCode,
      );
      _showSuccess('Số điện thoại bảo mật đã được thay đổi.'.tr);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _signOutAllDevices(BuildContext context) async {
    final password = await _showSensitiveConfirmation(
      context,
      title: 'Đăng xuất tất cả thiết bị?'.tr,
      message:
          'Tất cả phiên đăng nhập, bao gồm thiết bị này, sẽ bị thu hồi.'.tr,
      confirmLabel: 'Đăng xuất tất cả'.tr,
    );
    if (password == null) return;
    if (!context.mounted) return;

    try {
      if (!await _reauthenticate(context, password: password)) return;
      await controller.revokeAllSessions();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final input = await _showDeleteDialog(context);
    if (input == null) return;
    if (!context.mounted) return;

    try {
      if (!await _reauthenticate(context, password: input.password)) return;
      await controller.deleteAccount();
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _reauthenticate(
    BuildContext context, {
    required String password,
  }) async {
    final challenge = await controller.reauthenticate(
      currentPassword:
          controller.requiresPasswordReauthentication ? password : null,
    );
    if (challenge == null || challenge.verificationId.isEmpty) return true;
    if (!context.mounted) return false;

    final smsCode = await _showOtpDialog(
      context,
      phoneNumber: challenge.maskedPhoneNumber,
    );
    if (smsCode == null) return false;
    await controller.completeMfaReauthentication(
      challenge: challenge,
      smsCode: smsCode,
    );
    return true;
  }

  Future<_EmailChangeInput?> _showEmailDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var obscure = true;
    String? validationMessage;

    final result = await showDialog<_EmailChangeInput>(
      context: context,
      builder:
          (dialogContext) => _DialogControllerScope(
            controllers: [emailController, passwordController],
            child: StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    title: Text('Đổi email'.tr),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Email mới'.tr,
                              errorText: validationMessage,
                            ),
                          ),
                          if (controller.requiresPasswordReauthentication) ...[
                            const SizedBox(height: 12),
                            _PasswordField(
                              controller: passwordController,
                              label: 'Mật khẩu hiện tại'.tr,
                              obscure: obscure,
                              onToggle:
                                  () => setState(() => obscure = !obscure),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Chúng tôi sẽ gửi liên kết xác minh đến email mới.'
                                .tr,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Hủy'.tr),
                      ),
                      FilledButton(
                        onPressed: () {
                          final email = emailController.text.trim();
                          final password = passwordController.text;
                          if (!GetUtils.isEmail(email)) {
                            setState(
                              () =>
                                  validationMessage = 'Email không hợp lệ.'.tr,
                            );
                            return;
                          }
                          if (email.toLowerCase() ==
                              controller.account.value?.email.toLowerCase()) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Email mới phải khác email hiện tại.'.tr,
                            );
                            return;
                          }
                          if (controller.requiresPasswordReauthentication &&
                              password.isEmpty) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Vui lòng nhập mật khẩu hiện tại.'.tr,
                            );
                            return;
                          }
                          Navigator.pop(
                            dialogContext,
                            _EmailChangeInput(email: email, password: password),
                          );
                        },
                        child: Text('Gửi xác minh'.tr),
                      ),
                    ],
                  ),
            ),
          ),
    );
    return result;
  }

  Future<_PasswordChangeInput?> _showPasswordDialog(
    BuildContext context,
  ) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;
    String? validationMessage;

    final result = await showDialog<_PasswordChangeInput>(
      context: context,
      builder:
          (dialogContext) => _DialogControllerScope(
            controllers: [currentController, newController, confirmController],
            child: StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    title: Text('Đổi mật khẩu'.tr),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PasswordField(
                            controller: currentController,
                            label: 'Mật khẩu hiện tại'.tr,
                            obscure: obscureCurrent,
                            onToggle:
                                () => setState(
                                  () => obscureCurrent = !obscureCurrent,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _PasswordField(
                            controller: newController,
                            label: 'Mật khẩu mới'.tr,
                            obscure: obscureNew,
                            onToggle:
                                () => setState(() => obscureNew = !obscureNew),
                          ),
                          const SizedBox(height: 12),
                          _PasswordField(
                            controller: confirmController,
                            label: 'Xác nhận mật khẩu mới'.tr,
                            obscure: obscureNew,
                            onToggle:
                                () => setState(() => obscureNew = !obscureNew),
                          ),
                          if (validationMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              validationMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Hủy'.tr),
                      ),
                      FilledButton(
                        onPressed: () {
                          final current = currentController.text;
                          final next = newController.text;
                          final confirm = confirmController.text;
                          if (current.isEmpty) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Vui lòng nhập mật khẩu hiện tại.'.tr,
                            );
                            return;
                          }
                          if (next.length < 8) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Mật khẩu mới phải có ít nhất 8 ký tự.'
                                          .tr,
                            );
                            return;
                          }
                          if (next == current) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Mật khẩu mới phải khác mật khẩu hiện tại.'
                                          .tr,
                            );
                            return;
                          }
                          if (next != confirm) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Xác nhận mật khẩu không khớp.'.tr,
                            );
                            return;
                          }
                          Navigator.pop(
                            dialogContext,
                            _PasswordChangeInput(
                              currentPassword: current,
                              newPassword: next,
                            ),
                          );
                        },
                        child: Text('Cập nhật'.tr),
                      ),
                    ],
                  ),
            ),
          ),
    );
    return result;
  }

  Future<_PhoneChangeInput?> _showPhoneDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    var completePhone = '';
    var obscure = true;
    String? validationMessage;

    final result = await showDialog<_PhoneChangeInput>(
      context: context,
      builder:
          (dialogContext) => _DialogControllerScope(
            controllers: [passwordController],
            child: StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    title: Text('Đổi số điện thoại'.tr),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IntlPhoneField(
                            initialCountryCode: 'VN',
                            disableLengthCheck: true,
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại mới'.tr,
                              errorText: validationMessage,
                            ),
                            onChanged:
                                (phone) => completePhone = phone.completeNumber,
                          ),
                          if (controller.requiresPasswordReauthentication) ...[
                            const SizedBox(height: 4),
                            _PasswordField(
                              controller: passwordController,
                              label: 'Mật khẩu hiện tại'.tr,
                              obscure: obscure,
                              onToggle:
                                  () => setState(() => obscure = !obscure),
                            ),
                          ],
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Hủy'.tr),
                      ),
                      FilledButton(
                        onPressed: () {
                          final phone =
                              completePhone.replaceAll(' ', '').trim();
                          if (!RegExp(r'^\+\d{9,15}$').hasMatch(phone)) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Số điện thoại không hợp lệ.'.tr,
                            );
                            return;
                          }
                          final password = passwordController.text;
                          if (controller.requiresPasswordReauthentication &&
                              password.isEmpty) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Vui lòng nhập mật khẩu hiện tại.'.tr,
                            );
                            return;
                          }
                          Navigator.pop(
                            dialogContext,
                            _PhoneChangeInput(
                              phoneNumber: phone,
                              password: password,
                            ),
                          );
                        },
                        child: Text('Gửi OTP'.tr),
                      ),
                    ],
                  ),
            ),
          ),
    );
    return result;
  }

  Future<String?> _showOtpDialog(
    BuildContext context, {
    required String phoneNumber,
  }) async {
    final otpController = TextEditingController();
    String? validationMessage;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => _DialogControllerScope(
            controllers: [otpController],
            child: StatefulBuilder(
              builder: (context, setState) {
                final theme = Theme.of(context);
                final colors = theme.colorScheme;
                final hasError = validationMessage != null;
                const pinSpacing = 6.0;
                const totalPinSpacing = pinSpacing * 5;
                final dialogWidth =
                    (MediaQuery.sizeOf(context).width - 40)
                        .clamp(240.0, 400.0)
                        .toDouble();
                final pinAreaWidth =
                    (dialogWidth - 48).clamp(180.0, 352.0).toDouble();
                final pinWidth =
                    ((pinAreaWidth - totalPinSpacing) / 6)
                        .clamp(24.0, 48.0)
                        .toDouble();
                final pinInputWidth = pinWidth * 6 + totalPinSpacing;
                final pinTheme = PinTheme(
                  width: pinWidth,
                  height: 56,
                  textStyle: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outlineVariant,
                      width: 1.4,
                    ),
                  ),
                );

                return AlertDialog(
                  constraints: const BoxConstraints(maxWidth: 400),
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  title: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sms_outlined,
                          color: colors.primary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Xác nhận OTP'.tr, textAlign: TextAlign.center),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mã xác minh đã được gửi đến'.tr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          maskOtpPhoneNumber(phoneNumber),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: pinInputWidth,
                          child: Pinput(
                            length: 6,
                            controller: otpController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            autofillHints: const [AutofillHints.oneTimeCode],
                            separatorBuilder:
                                (_) => const SizedBox(width: pinSpacing),
                            defaultPinTheme: pinTheme,
                            focusedPinTheme: pinTheme.copyDecorationWith(
                              color: colors.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                color: colors.primary,
                                width: 2,
                              ),
                            ),
                            submittedPinTheme: pinTheme.copyDecorationWith(
                              color: colors.primary.withValues(alpha: 0.06),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.55),
                                width: 1.5,
                              ),
                            ),
                            errorPinTheme: pinTheme.copyDecorationWith(
                              color: colors.errorContainer.withValues(
                                alpha: 0.35,
                              ),
                              border: Border.all(
                                color: colors.error,
                                width: 1.8,
                              ),
                            ),
                            forceErrorState: hasError,
                            onChanged: (_) {
                              if (validationMessage == null) return;
                              setState(() => validationMessage = null);
                            },
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child:
                              validationMessage == null
                                  ? const SizedBox(height: 20)
                                  : Padding(
                                    key: ValueKey(validationMessage),
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      validationMessage!,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: colors.error),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Hủy'.tr),
                    ),
                    FilledButton(
                      onPressed: () {
                        final code = otpController.text.trim();
                        if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                          setState(
                            () =>
                                validationMessage = 'OTP phải gồm 6 chữ số.'.tr,
                          );
                          return;
                        }
                        Navigator.pop(dialogContext, code);
                      },
                      child: Text('Xác nhận'.tr),
                    ),
                  ],
                );
              },
            ),
          ),
    );
    return result;
  }

  Future<String?> _showSensitiveConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final passwordController = TextEditingController();
    var obscure = true;
    String? validationMessage;
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => _DialogControllerScope(
            controllers: [passwordController],
            child: StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    title: Text(title),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message),
                        if (controller.requiresPasswordReauthentication) ...[
                          const SizedBox(height: 16),
                          _PasswordField(
                            controller: passwordController,
                            label: 'Mật khẩu hiện tại'.tr,
                            obscure: obscure,
                            errorText: validationMessage,
                            onToggle: () => setState(() => obscure = !obscure),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            'Bạn sẽ được yêu cầu xác thực lại bằng Google.'.tr,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Hủy'.tr),
                      ),
                      FilledButton(
                        onPressed: () {
                          final password = passwordController.text;
                          if (controller.requiresPasswordReauthentication &&
                              password.isEmpty) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Vui lòng nhập mật khẩu hiện tại.'.tr,
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, password);
                        },
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
            ),
          ),
    );
    return result;
  }

  Future<_DeleteAccountInput?> _showDeleteDialog(BuildContext context) async {
    final confirmationController = TextEditingController();
    final passwordController = TextEditingController();
    var obscure = true;
    String? validationMessage;
    final errorColor = Theme.of(context).colorScheme.error;

    final result = await showDialog<_DeleteAccountInput>(
      context: context,
      builder:
          (dialogContext) => _DialogControllerScope(
            controllers: [confirmationController, passwordController],
            child: StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    title: Text(
                      'Xóa tài khoản vĩnh viễn?'.tr,
                      style: TextStyle(color: errorColor),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hồ sơ, thiết bị, dữ liệu bảo mật và nội dung công khai của bạn sẽ bị xóa. Hành động này không thể hoàn tác.'
                                .tr,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: confirmationController,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: '${'Nhập'.tr} XOA TAI KHOAN',
                              errorText: validationMessage,
                            ),
                          ),
                          if (controller.requiresPasswordReauthentication) ...[
                            const SizedBox(height: 12),
                            _PasswordField(
                              controller: passwordController,
                              label: 'Mật khẩu hiện tại'.tr,
                              obscure: obscure,
                              onToggle:
                                  () => setState(() => obscure = !obscure),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Text(
                              'Bạn sẽ được yêu cầu xác thực lại bằng Google.'
                                  .tr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Hủy'.tr),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: errorColor,
                        ),
                        onPressed: () {
                          final confirmation =
                              confirmationController.text.trim().toUpperCase();
                          final password = passwordController.text;
                          if (confirmation != 'XOA TAI KHOAN') {
                            setState(
                              () =>
                                  validationMessage =
                                      'Cụm từ xác nhận chưa chính xác.'.tr,
                            );
                            return;
                          }
                          if (controller.requiresPasswordReauthentication &&
                              password.isEmpty) {
                            setState(
                              () =>
                                  validationMessage =
                                      'Vui lòng nhập mật khẩu hiện tại.'.tr,
                            );
                            return;
                          }
                          Navigator.pop(
                            dialogContext,
                            _DeleteAccountInput(password: password),
                          );
                        },
                        child: Text('Xóa vĩnh viễn'.tr),
                      ),
                    ],
                  ),
            ),
          ),
    );
    return result;
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Thành công'.tr,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppTheme.successColor.withValues(alpha: 0.92),
      colorText: Colors.white,
    );
  }

  void _showError(Object error) =>
      _showErrorMessage(controller.messageFor(error));

  void _showErrorMessage(String message) {
    Get.snackbar(
      'Lỗi'.tr,
      message.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppTheme.errorColor.withValues(alpha: 0.92),
      colorText: Colors.white,
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _EmailVerificationStep extends StatelessWidget {
  const _EmailVerificationStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.titleColor,
    this.trailingLabel,
    this.trailingColor,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final String? trailingLabel;
  final Color? trailingColor;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          enabled: onTap != null || trailingLabel == null,
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: (iconColor ?? AppTheme.primaryColor).withValues(
              alpha: 0.12,
            ),
            child: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          trailing:
              trailingLabel == null
                  ? null
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trailingLabel!,
                        style: TextStyle(
                          color: trailingColor ?? AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right,
                          color: trailingColor ?? AppTheme.primaryColor,
                        ),
                    ],
                  ),
        ),
        if (showDivider) const Divider(height: 1, indent: 72),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.showDivider});

  final AccountDeviceModel device;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final lastActive = device.lastActiveAt;
    final dateText =
        lastActive == null
            ? 'Không rõ lần hoạt động cuối'.tr
            : '${'Hoạt động'.tr}: ${DateFormat('dd/MM/yyyy HH:mm').format(lastActive.toLocal())}';
    final statusColor =
        device.isActive ? AppTheme.successColor : Theme.of(context).hintColor;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.12),
            child: Icon(_platformIcon(device.platform), color: statusColor),
          ),
          title: Text(
            device.displayName.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('$dateText · ID ${device.shortId}'),
          trailing: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 72),
      ],
    );
  }

  IconData _platformIcon(String platform) {
    return switch (platform.toLowerCase()) {
      'android' => Icons.android,
      'ios' => Icons.phone_iphone,
      'web' => Icons.language,
      'windows' || 'macos' || 'linux' => Icons.computer,
      _ => Icons.devices_other,
    };
  }
}

/// Keeps text controllers alive for the entire dialog exit animation.
///
/// `showDialog` completes as soon as the route is popped, before its widget tree
/// is necessarily unmounted. Disposing controllers after awaiting `showDialog`
/// can therefore leave a closing TextField with an already disposed controller.
class _DialogControllerScope extends StatefulWidget {
  const _DialogControllerScope({
    required this.controllers,
    required this.child,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_DialogControllerScope> createState() => _DialogControllerScopeState();
}

class _DialogControllerScopeState extends State<_DialogControllerScope> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}

class _BlockingProgress extends StatelessWidget {
  const _BlockingProgress();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.25),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.security_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message.isEmpty
                  ? 'Không thể tải thông tin bảo mật.'.tr
                  : message.tr,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text('Thử lại'.tr)),
          ],
        ),
      ),
    );
  }
}

class _EmailChangeInput {
  const _EmailChangeInput({required this.email, required this.password});
  final String email;
  final String password;
}

class _PasswordChangeInput {
  const _PasswordChangeInput({
    required this.currentPassword,
    required this.newPassword,
  });
  final String currentPassword;
  final String newPassword;
}

class _PhoneChangeInput {
  const _PhoneChangeInput({required this.phoneNumber, required this.password});
  final String phoneNumber;
  final String password;
}

class _DeleteAccountInput {
  const _DeleteAccountInput({required this.password});
  final String password;
}
