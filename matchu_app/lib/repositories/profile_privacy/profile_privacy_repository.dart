import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/profile_privacy_settings.dart';

class ProfilePrivacyRepository {
  ProfilePrivacyRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Phiên đăng nhập đã hết hạn.');
    }
    return uid;
  }

  Future<ProfilePrivacySettings> getCurrentSettings() async {
    final snapshot = await _firestore.collection('users').doc(_uid).get();
    if (!snapshot.exists) {
      throw StateError('Không tìm thấy hồ sơ người dùng.');
    }
    return ProfilePrivacySettings.fromJson(snapshot.data());
  }

  Future<void> setFollowingListVisibility(
    FollowingListVisibility visibility,
  ) async {
    await _firestore.collection('users').doc(_uid).update({
      'followingListVisibility': visibility.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPrivateAccount(bool enabled) async {
    await _firestore.collection('users').doc(_uid).update({
      'isPrivateAccount': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
