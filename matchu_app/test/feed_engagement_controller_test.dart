import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/controllers/feed/feed_engagement_controller.dart';
import 'package:matchu_app/services/feed/feed_engagement_repository.dart';

void main() {
  test(
    'explicit interactions are immediately available to refresh exclusion',
    () {
      final controller = FeedEngagementController(repository: _FakeWriter());

      controller.markInteracted('post-1');
      controller.markInteracted('post-2');
      controller.markInteracted('post-1');

      expect(controller.recentPostIds(), <String>['post-1', 'post-2']);
      controller.onClose();
    },
  );

  test(
    'flush waits for exposure persistence and marks a qualified view',
    () async {
      final writer = _FakeWriter();
      final controller = FeedEngagementController(repository: writer);

      controller.updateVisibility('viewed-post', 0.8);
      await Future<void>.delayed(const Duration(milliseconds: 510));
      await controller.flushVisibleAndWait();

      expect(controller.recentPostIds(), contains('viewed-post'));
      expect(writer.exposures, hasLength(1));
      expect(writer.exposures.single.postId, 'viewed-post');
      expect(writer.exposures.single.dwellMs, greaterThanOrEqualTo(500));
      controller.onClose();
    },
  );
}

class _FakeWriter implements FeedEngagementWriter {
  final List<({String postId, int dwellMs, String source})> exposures = [];

  @override
  Future<void> recordExposure({
    required String postId,
    required int dwellMs,
    required String source,
  }) async {
    exposures.add((postId: postId, dwellMs: dwellMs, source: source));
  }
}
