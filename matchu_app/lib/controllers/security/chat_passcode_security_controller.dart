import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:matchu_app/models/security/chat_passcode_status.dart';
import 'package:matchu_app/repositories/account_security/account_security_repository.dart';
import 'package:matchu_app/repositories/security/chat_passcode_security_repository.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum DestructiveResetResult { completed, needsMfa, failed }

class ChatPasscodeSecurityController extends GetxController {
  ChatPasscodeSecurityController({
    required ChatPasscodeSecurityRepository repository,
  }) : _repository = repository;

  final ChatPasscodeSecurityRepository _repository;

  final status = Rxn<ChatPasscodeStatus>();
  final isLoading = true.obs;
  final isActionRunning = false.obs;
  final isMfaPending = false.obs;
  final errorMessage = ''.obs;

  MfaReauthenticationChallenge? _pendingMfaChallenge;
  String? _pendingResetPasscode;

  bool get hasPasswordProvider => _repository.hasPasswordProvider;
  String get mfaPhoneNumber => _pendingMfaChallenge?.maskedPhoneNumber ?? '';

  @override
  void onInit() {
    super.onInit();
    loadStatus();
  }

  Future<void> loadStatus() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      status.value = await _repository.loadStatus();
    } catch (error) {
      errorMessage.value = messageFor(error);
    } finally {
      isLoading.value = false;
    }
  }

  String? validateNewPasscode(String pin, String confirmation) {
    if (!PasscodeBackupService.isValidPasscode(pin)) {
      return 'Mã PIN phải gồm đúng 6 chữ số.';
    }
    if (pin.trim() != confirmation.trim()) {
      return 'Mã PIN xác nhận không khớp.';
    }
    return null;
  }

  Future<bool> changePasscode({
    required String currentPasscode,
    required String newPasscode,
    required String confirmation,
  }) async {
    final validation = validateNewPasscode(newPasscode, confirmation);
    if (validation != null) {
      errorMessage.value = validation;
      return false;
    }
    if (!PasscodeBackupService.isValidPasscode(currentPasscode)) {
      errorMessage.value = 'Mã PIN hiện tại phải gồm đúng 6 chữ số.';
      return false;
    }

    return _runAction(() async {
      await _repository.changePasscode(
        currentPasscode: currentPasscode,
        newPasscode: newPasscode,
      );
      await loadStatus();
    });
  }

  Future<bool> recoverWithFace({
    required String newPasscode,
    required String confirmation,
  }) async {
    final validation = validateNewPasscode(newPasscode, confirmation);
    if (validation != null) {
      errorMessage.value = validation;
      return false;
    }

    errorMessage.value = '';
    final result = await Get.toNamed(
      AppRouter.faceVerification,
      arguments: const <String, dynamic>{'mode': 'reauth'},
    );
    final sessionId =
        result is Map && result['sessionId'] is String
            ? (result['sessionId'] as String).trim()
            : '';
    if (sessionId.isEmpty) {
      errorMessage.value = 'Xác thực khuôn mặt chưa hoàn tất.';
      return false;
    }

    return _runAction(() async {
      final recovered = await _repository.recoverWithFaceSession(
        sessionId: sessionId,
        newPasscode: newPasscode,
      );
      if (!recovered) {
        throw StateError(
          'Không thể khôi phục khóa bằng khuôn mặt. Vui lòng thử lại.',
        );
      }
      await loadStatus();
    });
  }

  Future<DestructiveResetResult> startDestructiveReset({
    required String currentPassword,
    required String newPasscode,
    required String confirmation,
  }) async {
    final validation = validateNewPasscode(newPasscode, confirmation);
    if (validation != null) {
      errorMessage.value = validation;
      return DestructiveResetResult.failed;
    }
    if (hasPasswordProvider && currentPassword.isEmpty) {
      errorMessage.value = 'Vui lòng nhập mật khẩu tài khoản hiện tại.';
      return DestructiveResetResult.failed;
    }
    if (isActionRunning.value) return DestructiveResetResult.failed;

    isActionRunning.value = true;
    errorMessage.value = '';
    try {
      final challenge = await _repository.reauthenticate(
        currentPassword: hasPasswordProvider ? currentPassword : null,
      );
      if (challenge != null && challenge.verificationId.isNotEmpty) {
        _pendingMfaChallenge = challenge;
        _pendingResetPasscode = newPasscode;
        isMfaPending.value = true;
        return DestructiveResetResult.needsMfa;
      }

      await _repository.destructiveReset(newPasscode);
      await loadStatus();
      return DestructiveResetResult.completed;
    } catch (error) {
      errorMessage.value = messageFor(error);
      return DestructiveResetResult.failed;
    } finally {
      isActionRunning.value = false;
    }
  }

  Future<bool> completeMfaReset(String smsCode) async {
    final challenge = _pendingMfaChallenge;
    final newPasscode = _pendingResetPasscode;
    if (challenge == null || newPasscode == null) {
      errorMessage.value = 'Phiên xác thực MFA không còn hợp lệ.';
      return false;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(smsCode.trim())) {
      errorMessage.value = 'OTP phải gồm đúng 6 chữ số.';
      return false;
    }

    return _runAction(() async {
      await _repository.completeMfaReauthentication(
        challenge: challenge,
        smsCode: smsCode.trim(),
      );
      await _repository.destructiveReset(newPasscode);
      _pendingMfaChallenge = null;
      _pendingResetPasscode = null;
      isMfaPending.value = false;
      await loadStatus();
    });
  }

  void cancelPendingMfa() {
    _pendingMfaChallenge = null;
    _pendingResetPasscode = null;
    isMfaPending.value = false;
    errorMessage.value = '';
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    if (isActionRunning.value) return false;
    isActionRunning.value = true;
    errorMessage.value = '';
    try {
      await action();
      return true;
    } catch (error) {
      errorMessage.value = messageFor(error);
      return false;
    } finally {
      isActionRunning.value = false;
    }
  }

  String messageFor(Object error) {
    if (error is PasscodeVerificationException) {
      return 'Mã PIN hiện tại không đúng.';
    }
    if (error is FirebaseAuthException) {
      return firebaseErrorToVietnamese(error.code);
    }
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'failed-precondition':
          return 'Vui lòng xác thực lại tài khoản trước khi đặt lại PIN.';
        case 'unauthenticated':
          return 'Phiên đăng nhập không còn hiệu lực.';
        default:
          return error.message ?? 'Không thể hoàn tất thao tác mã PIN.';
      }
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Bạn đã hủy xác thực tài khoản Google.';
        case GoogleSignInExceptionCode.userMismatch:
          return 'Vui lòng chọn đúng tài khoản Google đang đăng nhập.';
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'Cấu hình đăng nhập Google chưa hợp lệ. Vui lòng thử lại sau.';
        case GoogleSignInExceptionCode.uiUnavailable:
        case GoogleSignInExceptionCode.interrupted:
          return 'Không thể mở xác thực Google lúc này. Vui lòng thử lại.';
        case GoogleSignInExceptionCode.unknownError:
          return error.description ?? 'Không thể xác thực tài khoản Google.';
      }
    }
    final message =
        error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', '')
            .trim();
    return message.isEmpty ? 'Đã xảy ra lỗi. Vui lòng thử lại.' : message;
  }
}
