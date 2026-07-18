import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/account_security/account_security_model.dart';
import 'package:matchu_app/repositories/account_security/account_security_repository.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

class AccountSecurityController extends GetxController {
  AccountSecurityController({AccountSecurityRepository? repository})
    : _repository = repository ?? AccountSecurityRepository();

  final AccountSecurityRepository _repository;

  final account = Rxn<AccountSecurityInfo>();
  final devices = <AccountDeviceModel>[].obs;
  final isLoading = true.obs;
  final isActionRunning = false.obs;
  final errorMessage = ''.obs;

  StreamSubscription<List<AccountDeviceModel>>? _deviceSubscription;

  bool get canChangePassword => account.value?.hasPasswordProvider == true;
  bool get requiresPasswordReauthentication =>
      account.value?.hasPasswordProvider == true;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      account.value = await _repository.loadAccountInfo();
      final currentDeviceId = await _repository.currentDeviceId();
      await _deviceSubscription?.cancel();
      _deviceSubscription = _repository
          .watchDevices(currentDeviceId: currentDeviceId)
          .listen(
            devices.assignAll,
            onError: (Object error) {
              errorMessage.value = messageFor(error);
            },
          );
    } catch (error) {
      errorMessage.value = messageFor(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<MfaReauthenticationChallenge?> reauthenticate({
    String? currentPassword,
  }) {
    return _runAction(
      () => _repository.reauthenticate(currentPassword: currentPassword),
    );
  }

  Future<void> completeMfaReauthentication({
    required MfaReauthenticationChallenge challenge,
    required String smsCode,
  }) {
    return _runAction(
      () => _repository.completeMfaReauthentication(
        challenge: challenge,
        smsCode: smsCode,
      ),
    );
  }

  Future<void> requestEmailChange(String newEmail) async {
    await _runAction(() => _repository.requestEmailChange(newEmail));
  }

  Future<void> changePassword(String newPassword) async {
    final currentEmail = account.value?.email ?? '';
    await _runAction(() => _repository.updatePassword(newPassword));
    if (currentEmail.isNotEmpty && Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().forgetRememberedAccount(currentEmail);
    }
  }

  Future<PhoneChangeChallenge> startPhoneChange(String phoneNumber) {
    return _runAction(() => _repository.startPhoneChange(phoneNumber));
  }

  Future<void> completePhoneChange({
    required PhoneChangeChallenge challenge,
    required String smsCode,
  }) async {
    await _runAction(
      () => _repository.completePhoneChange(
        challenge: challenge,
        smsCode: smsCode,
      ),
    );
    await load();
  }

  Future<void> revokeAllSessions() async {
    await _runAction(_repository.revokeAllSessions);
    await _logoutLocally();
  }

  Future<void> deleteAccount() async {
    final currentEmail = account.value?.email ?? '';
    await _runAction(_repository.deleteAccount);
    if (currentEmail.isNotEmpty && Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().forgetRememberedAccount(currentEmail);
    }
    await _logoutLocally();
  }

  Future<void> _logoutLocally() async {
    if (Get.isRegistered<AuthController>()) {
      // The callable already revoked/deleted remote device state. Skipping
      // remote logout writes prevents the client from recreating a device
      // document after permanent account deletion.
      await Get.find<AuthController>().logoutC(skipRemoteUpdates: true);
      return;
    }
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed('/welcome');
  }

  Future<T> _runAction<T>(Future<T> Function() action) async {
    if (isActionRunning.value) {
      throw StateError('Một thao tác bảo mật khác đang được xử lý.');
    }
    isActionRunning.value = true;
    try {
      return await action();
    } finally {
      isActionRunning.value = false;
    }
  }

  String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return firebaseErrorToVietnamese(error.code);
    }
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Phiên đăng nhập không còn hiệu lực.';
        case 'failed-precondition':
          return 'Vui lòng xác thực lại trước khi tiếp tục.';
        case 'resource-exhausted':
          return 'Yêu cầu đang được xử lý. Vui lòng thử lại sau.';
        default:
          return error.message ?? 'Không thể hoàn tất thao tác bảo mật.';
      }
    }
    if (error is TimeoutException) {
      return 'Đã hết thời gian chờ. Vui lòng thử lại.';
    }

    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    return message.isEmpty ? 'Đã xảy ra lỗi. Vui lòng thử lại.' : message;
  }

  @override
  void onClose() {
    _deviceSubscription?.cancel();
    super.onClose();
  }
}
