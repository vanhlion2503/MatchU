import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/comment_report_model.dart';

class CommentReportService {
  CommentReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> submitReport(CommentReportModel report) async {
    final fromUid = report.fromUid.trim();
    final toUid = report.toUid.trim();
    final postId = report.postId.trim();
    final commentId = report.commentId.trim();

    if ([fromUid, toUid, postId, commentId].any((value) => value.isEmpty)) {
      throw StateError('Thiếu thông tin báo cáo bình luận.');
    }
    if (fromUid == toUid) {
      throw StateError('Bạn không thể báo cáo bình luận của chính mình.');
    }

    final reportRef = _firestore.collection('commentReports').doc();
    final userRef = _firestore.collection('users').doc(toUid);
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final postSnap = await transaction.get(postRef);
      final commentSnap = await transaction.get(commentRef);

      if (!userSnap.exists) {
        throw StateError('Không tìm thấy người dùng đã viết bình luận.');
      }
      if (!postSnap.exists) {
        throw StateError('Bài viết không còn tồn tại.');
      }
      if (!commentSnap.exists) {
        throw StateError('Bình luận không còn tồn tại.');
      }

      final commentAuthorId =
          (commentSnap.data()?['userId'] ?? '').toString().trim();
      if (commentAuthorId != toUid) {
        throw StateError('Thông tin tác giả bình luận không khớp.');
      }

      final rawTotal = userSnap.data()?['totalReports'];
      final currentTotal = rawTotal is num ? rawTotal.toInt() : 0;
      transaction.set(reportRef, report.toJson());
      transaction.update(userRef, {'totalReports': currentTotal + 1});
    });
  }
}
