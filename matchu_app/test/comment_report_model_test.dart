import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/comment_report_model.dart';

void main() {
  test('comment report points admins to retained moderation evidence', () {
    final report = CommentReportModel(
      fromUid: 'reporter',
      toUid: 'comment-author',
      postId: 'post-1',
      commentId: 'comment-1',
      categoryKey: 'harassment',
      categoryTitle: 'Quấy rối hoặc xúc phạm',
      reasonKey: 'personal_insults',
      reasonTitle: 'Chửi bới, hạ nhục hoặc công kích cá nhân',
      createdAt: DateTime.utc(2026, 7, 29),
    );

    expect(
      report.toJson()['moderationEvidencePath'],
      'posts/post-1/comments/comment-1/moderationEvidence/original',
    );
  });
}
