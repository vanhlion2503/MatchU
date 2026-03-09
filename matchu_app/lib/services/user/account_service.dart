import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<bool> isNicknameUnique(String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) return false;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final snap =
        await _db
            .collection('users')
            .where('nickname', isEqualTo: normalized)
            .limit(1)
            .get();

    if (snap.docs.isEmpty) return true;

    return snap.docs.first.id == currentUser.uid;
  }

  Future<void> updateBasicProfile({
    required String fullname,
    required String nickname,
    required String gender,
    required DateTime birthday,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User chưa đăng nhập");
    }

    final normalizedFullname = fullname.trim();
    final normalizedNickname = nickname.trim();

    // 1) Update displayName (Auth)
    if (user.displayName != normalizedNickname) {
      await user.updateDisplayName(normalizedNickname);
    }

    // 2) Update Firestore
    await _db.collection('users').doc(user.uid).update({
      "fullname": normalizedFullname,
      "nickname": normalizedNickname,
      "gender": gender, // male / female / other
      "birthday": birthday.toIso8601String(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }
}
