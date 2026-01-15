import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ID người dùng hiện tại
  String get uid => _auth.currentUser!.uid;

  // ================================================================
  // 🔥 STREAM USER REALTIME
  // ================================================================
  Stream<UserModel?> streamUser(String uid) {
    return _db.collection("users").doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!, doc.id);
    });
  }

  // ================================================================
  // 🔥 GET USER MODEL
  // ================================================================
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!, doc.id);
  }

  // ================================================================
  // 🔥 GET USER RAW MAP
  // ================================================================
  Future<Map<String, dynamic>?> getUserRaw(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    return doc.data();
  }

  // ================================================================
  // 🔥 UPDATE USER (MERGE SAFELY)
  // ================================================================
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).set(data, SetOptions(merge: true));
  }

  // ================================================================
  // 🔥 SEARCH BY NICKNAME
  // (dùng index prefix để tìm cực nhanh)
  // ================================================================
  Future<List<UserModel>> searchUsersByNickname(String query) async {
    query = query.trim();
    if (query.isEmpty) return [];

    try {
      final result = await _db
          .collection("users")
          .where("nickname", isGreaterThanOrEqualTo: query)
          .where("nickname", isLessThan: query + '\uf8ff')
          .limit(20)
          .get();

      return result.docs
          .map((doc) => UserModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ================================================================
  // 🔥 FOLLOW USER
  // ================================================================
  Future<void> followUser(String targetUserId) async {
    try {
      final batch = _db.batch();

      final currentUserRef = _db.collection("users").doc(uid);
      final targetUserRef = _db.collection("users").doc(targetUserId);

      batch.update(currentUserRef, {
        "following": FieldValue.arrayUnion([targetUserId]),
      });

      batch.update(targetUserRef, {
        "followers": FieldValue.arrayUnion([uid]),
      });

      await batch.commit();
    } catch (e) {
      print("⚠ followUser error: $e");
    }
  }

  // ================================================================
  // 🔥 UNFOLLOW USER
  // ================================================================
  Future<void> unfollowUser(String targetUserId) async {
    try {
      final batch = _db.batch();

      final currentUserRef = _db.collection("users").doc(uid);
      final targetUserRef = _db.collection("users").doc(targetUserId);

      batch.update(currentUserRef, {
        "following": FieldValue.arrayRemove([targetUserId]),
      });

      batch.update(targetUserRef, {
        "followers": FieldValue.arrayRemove([uid]),
      });

      await batch.commit();
    } catch (e) {
      print("⚠ unfollowUser error: $e");
    }
  }

  // ================================================================
  // 🔥 CHECK IF CURRENT USER IS FOLLOWING TARGET USER
  // ================================================================
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final snap = await _db.collection("users").doc(uid).get();

      if (!snap.exists) return false;

      final data = snap.data() as Map<String, dynamic>?;

      final following = List<String>.from(data?["following"] ?? []);
      return following.contains(targetUserId);
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUserLocation({
    required double lat,
    required double lng,
  }) async {
    await _db.collection("users").doc(uid).set({
      "location": {
        "lat": lat,
        "lng": lng,
      },
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


}
