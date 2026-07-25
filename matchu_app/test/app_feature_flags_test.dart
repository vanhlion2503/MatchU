import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/config/app_feature_flags.dart';

void main() {
  test('video matching face verification uses the compile-time flag', () {
    const expected = bool.fromEnvironment(
      'VIDEO_MATCHING_FACE_VERIFICATION_ENABLED',
      defaultValue: true,
    );

    expect(AppFeatureFlags.videoMatchingFaceVerificationEnabled, expected);
  });
}
