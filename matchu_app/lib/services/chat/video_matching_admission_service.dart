import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:matchu_app/repositories/matching/video_matching_admission_repository.dart';
import 'package:matchu_app/services/security/device_service.dart';

class VideoMatchingAdmissionService
    implements VideoMatchingAdmissionRepository {
  VideoMatchingAdmissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<bool> isFaceEnrolled() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data()?['isFaceVerified'] == true;
  }

  @override
  Future<String> getDeviceId() => DeviceService.getDeviceId();

  @override
  Future<void> revokeProof({
    required String proofId,
    required String deviceId,
  }) async {
    await _functions.httpsCallable('revokeVideoMatchingFaceProof').call({
      'faceProofId': proofId,
      'deviceId': deviceId,
    });
  }
}
