import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:matchu_app/controllers/user/account_security_controller.dart';
import 'package:matchu_app/models/account_security/account_security_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/translation_keys.dart';

class AccountSecurityView extends GetView<AccountSecurityController> {
  const AccountSecurityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationKeys.accountSecurity.tr)),
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
                children: [
                  _accountSection(context, controller.account.value!),
                  const SizedBox(height: 22),
                  _securitySection(context),
                  const SizedBox(height: 22),
                  _deviceSection(context),
                  const SizedBox(height: 22),
                  _accountManagementSection(context),
                ],
              ),
            ),
            if (controller.isActionRunning.value)
              const Positioned.fill(child: _BlockingProgress()),
          ],
        );
      }),
    );
  }

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
      _showSuccess(
        'Đã gửi liên kết xác minh đến email mới. Email sẽ thay đổi sau khi bạn xác nhận.'
            .tr,
      );
    } catch (error) {
      _showError(error);
    }
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
          (dialogContext) => StatefulBuilder(
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
                            onToggle: () => setState(() => obscure = !obscure),
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
                            () => validationMessage = 'Email không hợp lệ.'.tr,
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
    );
    emailController.dispose();
    passwordController.dispose();
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
          (dialogContext) => StatefulBuilder(
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
                                    'Mật khẩu mới phải có ít nhất 8 ký tự.'.tr,
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
    );
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
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
          (dialogContext) => StatefulBuilder(
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
                            onToggle: () => setState(() => obscure = !obscure),
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
                        final phone = completePhone.replaceAll(' ', '').trim();
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
    );
    passwordController.dispose();
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
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Xác nhận OTP'.tr),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${'Mã xác minh đã được gửi đến'.tr} $phoneNumber'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Mã OTP'.tr,
                          errorText: validationMessage,
                        ),
                      ),
                    ],
                  ),
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
                ),
          ),
    );
    otpController.dispose();
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
          (dialogContext) => StatefulBuilder(
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
    );
    passwordController.dispose();
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
          (dialogContext) => StatefulBuilder(
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
    );
    confirmationController.dispose();
    passwordController.dispose();
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
