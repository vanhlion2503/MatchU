import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/security/chat_passcode_status.dart';
import 'package:matchu_app/repositories/account_security/account_security_repository.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';

class ChatPasscodeSecurityRepository {
  ChatPasscodeSecurityRepository({
    AccountSecurityRepository? accountSecurityRepository,
    FirebaseAuth? auth,
  }) : _accountSecurityRepository =
           accountSecurityRepository ?? AccountSecurityRepository(),
       _auth = auth ?? FirebaseAuth.instance;

  final AccountSecurityRepository _accountSecurityRepository;
  final FirebaseAuth _auth;

  bool get hasPasswordProvider {
    final providers = _auth.currentUser?.providerData ?? const [];
    return providers.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  Future<ChatPasscodeStatus> loadStatus() async {
    final results = await Future.wait<Object>([
      PasscodeBackupService.hasBackupOnServer(),
      PasscodeBackupService.hasLocalBackupKey(),
      PasscodeBackupService.isHistoryLocked(),
      PasscodeBackupService.getFaceRecoveryBackupStatus(),
    ]);
    final faceStatus = results[3] as FaceRecoveryBackupStatus;
    return ChatPasscodeStatus(
      isConfigured: results[0] as bool,
      isUnlockedOnDevice: results[1] as bool,
      isHistoryLocked: results[2] as bool,
      isFaceVerified: faceStatus.faceVerified,
      isFaceRecoveryAvailable: faceStatus.backupAvailable,
    );
  }

  Future<void> changePasscode({
    required String currentPasscode,
    required String newPasscode,
  }) {
    return PasscodeBackupService.changePasscode(
      currentPasscode: currentPasscode,
      newPasscode: newPasscode,
    );
  }

  Future<bool> recoverWithFaceSession({
    required String sessionId,
    required String newPasscode,
  }) async {
    final recovered = await PasscodeBackupService.unlockWithFaceSession(
      sessionId,
    );
    if (!recovered) return false;
    await PasscodeBackupService.replacePasscodeAfterRecovery(newPasscode);
    return true;
  }

  Future<MfaReauthenticationChallenge?> reauthenticate({
    String? currentPassword,
  }) {
    return _accountSecurityRepository.reauthenticate(
      currentPassword: currentPassword,
    );
  }

  Future<void> completeMfaReauthentication({
    required MfaReauthenticationChallenge challenge,
    required String smsCode,
  }) {
    return _accountSecurityRepository.completeMfaReauthentication(
      challenge: challenge,
      smsCode: smsCode,
    );
  }

  Future<void> destructiveReset(String newPasscode) {
    return PasscodeBackupService.resetPasscodeWithNewValue(newPasscode);
  }
}
