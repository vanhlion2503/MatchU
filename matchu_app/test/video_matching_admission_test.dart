import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/controllers/matching/video_matching_admission_controller.dart';
import 'package:matchu_app/repositories/matching/video_matching_admission_repository.dart';

void main() {
  test('video admission controller starts without a cached proof', () {
    final controller = VideoMatchingAdmissionController(
      repository: _FakeAdmissionRepository(),
    );

    expect(controller.currentProof, isNull);
  });
}

class _FakeAdmissionRepository implements VideoMatchingAdmissionRepository {
  @override
  Future<String> getDeviceId() async => 'device-a';

  @override
  Future<bool> isFaceEnrolled() async => true;

  @override
  Future<void> revokeProof({
    required String proofId,
    required String deviceId,
  }) async {}
}
