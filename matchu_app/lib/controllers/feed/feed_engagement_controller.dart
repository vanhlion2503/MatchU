import 'dart:async';

import 'package:get/get.dart';
import 'package:matchu_app/services/feed/feed_engagement_repository.dart';

class FeedEngagementController extends GetxController {
  FeedEngagementController({FeedEngagementRepository? repository})
    : _repository = repository ?? FeedEngagementRepository();

  final FeedEngagementRepository _repository;
  final Map<String, DateTime> _visibleSince = <String, DateTime>{};

  void updateVisibility(String postId, double visibleFraction) {
    final id = postId.trim();
    if (id.isEmpty) return;
    if (visibleFraction >= 0.6) {
      _visibleSince.putIfAbsent(id, DateTime.now);
    } else {
      _flush(id);
    }
  }

  void _flush(String postId) {
    final startedAt = _visibleSince.remove(postId);
    if (startedAt == null) return;
    final dwellMs = DateTime.now().difference(startedAt).inMilliseconds;
    unawaited(
      _repository.recordExposure(
        postId: postId,
        dwellMs: dwellMs,
        source: 'feed',
      ),
    );
  }

  @override
  void onClose() {
    for (final postId in _visibleSince.keys.toList(growable: false)) {
      _flush(postId);
    }
    super.onClose();
  }
}
