import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract interface class FeedEngagementWriter {
  Future<void> recordExposure({
    required String postId,
    required int dwellMs,
    required String source,
  });
}

class FeedEngagementRepository implements FeedEngagementWriter {
  FeedEngagementRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
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
      final now = DateTime.now();
      final currentWindowStart =
          (snapshot.data()?['frequencyWindowStartedAt'] as Timestamp?)
              ?.toDate();
      final isCurrentWindow =
          currentWindowStart != null &&
          now.difference(currentWindowStart) < const Duration(hours: 24);
      final data = <String, dynamic>{
        'userId': uid,
        'postId': normalizedPostId,
        'source': source,
        'impressionCount': FieldValue.increment(1),
        'totalDwellMs': FieldValue.increment(dwellMs.clamp(0, 120000)),
        'lastDwellMs': dwellMs.clamp(0, 120000),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'impressionCount24h': isCurrentWindow ? FieldValue.increment(1) : 1,
      };
      if (!isCurrentWindow) {
        data['frequencyWindowStartedAt'] = FieldValue.serverTimestamp();
      }
      if (!snapshot.exists) data['firstSeenAt'] = FieldValue.serverTimestamp();
      transaction.set(ref, data, SetOptions(merge: true));
    });
  }
}
