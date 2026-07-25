abstract final class AppFeatureFlags {
  /// Controls the face enrollment/reauthentication gate before video matching.
  ///
  /// This defaults to enabled so existing builds keep their current behavior.
  /// Disable only for testing with:
  /// --dart-define=VIDEO_MATCHING_FACE_VERIFICATION_ENABLED=false
  static const bool videoMatchingFaceVerificationEnabled = bool.fromEnvironment(
    'VIDEO_MATCHING_FACE_VERIFICATION_ENABLED',
    defaultValue: true,
  );
}
