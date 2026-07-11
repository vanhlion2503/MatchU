import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedEngagementRepository {
  FeedEngagementRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> recordExposure({
    required String postId,
    required int dwellMs,
    required String source,
  }) async {
    final uid = _auth.currentUser?.uid.trim() ?? '';
    final normalizedPostId = postId.trim();
    if (uid.isEmpty || normalizedPostId.isEmpty || dwellMs < 500) return;

    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('feedImpressions')
        .doc(normalizedPostId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = <String, dynamic>{
        'userId': uid,
        'postId': normalizedPostId,
        'source': source,
        'impressionCount': FieldValue.increment(1),
        'totalDwellMs': FieldValue.increment(dwellMs.clamp(0, 120000)),
        'lastDwellMs': dwellMs.clamp(0, 120000),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists) data['firstSeenAt'] = FieldValue.serverTimestamp();
      transaction.set(ref, data, SetOptions(merge: true));
    });
  }
}
