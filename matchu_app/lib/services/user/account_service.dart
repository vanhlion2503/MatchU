import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<bool> isNicknameUnique(String nickname) async {
    final snap = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return true;

    return snap.docs.first.id == _auth.currentUser!.uid;
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

    // 1️⃣ Update displayName (Auth)
    if (user.displayName != nickname) {
      await user.updateDisplayName(nickname);
    }

    // 2️⃣ Update Firestore
    await _db.collection('users').doc(user.uid).update({
      "fullname": fullname,
      "nickname": nickname,
      "gender": gender, // male / female / other
      "birthday": birthday.toIso8601String(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }
}
