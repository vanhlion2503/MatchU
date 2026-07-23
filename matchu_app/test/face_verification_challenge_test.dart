import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/controllers/verification/face_verification_controller.dart';
import 'package:matchu_app/services/verification/face_verification_service.dart';

void main() {
  test('server liveness challenge requires blink and both turn actions', () {
    final challenge = FaceLivenessChallenge(
      id: 'challenge-a',
      actions: const ['center', 'blink', 'turn_left', 'turn_right'],
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );

    expect(challenge.isValid, isTrue);
    expect(FaceVerificationMode.reauthentication.name, 'reauthentication');
  });

  test('legacy three-step challenge is not accepted by the v2 client', () {
    final challenge = FaceLivenessChallenge(
      id: 'challenge-a',
      actions: const ['center', 'turn_left', 'turn_right'],
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );

    expect(challenge.isValid, isFalse);
  });
}
