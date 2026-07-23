abstract class VideoMatchingAdmissionRepository {
  Future<bool> isFaceEnrolled();

  Future<String> getDeviceId();

  Future<void> revokeProof({required String proofId, required String deviceId});
}
