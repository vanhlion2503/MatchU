import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';

void main() {
  test('chat PIN accepts exactly six digits', () {
    expect(PasscodeBackupService.isValidPasscode('123456'), isTrue);
    expect(PasscodeBackupService.isValidPasscode(' 123456 '), isTrue);
    expect(PasscodeBackupService.isValidPasscode('12345'), isFalse);
    expect(PasscodeBackupService.isValidPasscode('1234567'), isFalse);
    expect(PasscodeBackupService.isValidPasscode('12345a'), isFalse);
  });
}
