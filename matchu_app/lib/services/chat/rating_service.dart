import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/chat_rating_model.dart';

class RatingService {
  static final _db = FirebaseFirestore.instance;

  static String _ratingId(String roomId, String fromUid) => "${roomId}_$fromUid";

  static Future<void> autoRate({
    required String roomId,
    required String fromUid,
    required String toUid,
  }) async {
    await submitRating(
      ChatRatingModel(
        roomId: roomId,
        fromUid: fromUid,
        toUid: toUid,
        score: 5.0,
        skipped: false,
        createdAt: DateTime.now(),
      ),
    );
  }
  static Future<void> submitRating(ChatRatingModel rating) async {
    final ratingRef = _db
        .collection("chatRatings")
        .doc("${rating.roomId}_${rating.fromUid}");

    final userRef = _db.collection("users").doc(rating.toUid);

    await _db.runTransaction((tx) async {
      // ===================== 1️⃣ READ FIRST =====================
      final ratingSnap = await tx.get(ratingRef);
      if (ratingSnap.exists) return; // 🔒 chặn rate lại

      DocumentSnapshot<Map<String, dynamic>>? userSnap;

      // Chỉ đọc user nếu KHÔNG skip
      if (!rating.skipped) {
        userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;
      }

      // ===================== 2️⃣ WRITE AFTER =====================
      tx.set(ratingRef, rating.toJson());

      if (rating.skipped) return;

      final data = userSnap!.data()!;
      final oldTotal = (data["totalChatRatings"] ?? 0) as int;

      double newAvg;
      int newTotal = oldTotal + 1;

      if (oldTotal == 0) {
        // 🟢 Vote đầu tiên
        newAvg = rating.score;
      } else {
        final oldAvg = (data["avgChatRating"] ?? 5.0).toDouble();
        newAvg = ((oldAvg * oldTotal) + rating.score) / newTotal;
      }

      tx.update(userRef, {
        "avgChatRating": newAvg,
        "totalChatRatings": newTotal,
      });
    });
  }

}