import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/feed/feed_engagement_repository.dart';

class FeedEngagementController extends GetxController {
  FeedEngagementController({FeedEngagementWriter? repository})
    : _repository = repository ?? FeedEngagementRepository();

  final FeedEngagementWriter _repository;
  static const double _qualifiedVisibleFraction = 0.6;
  static const Duration _qualifiedVisibilityDuration = Duration(
    milliseconds: 800,
  );

  final Map<String, DateTime> _visibleSince = <String, DateTime>{};
  final Map<String, Timer> _qualificationTimers = <String, Timer>{};
  final LinkedHashSet<String> _recentPostIds = LinkedHashSet<String>();
  final Set<Future<void>> _pendingWrites = <Future<void>>{};

  void updateVisibility(String postId, double visibleFraction) {
    final id = postId.trim();
    if (id.isEmpty) return;
    if (visibleFraction >= _qualifiedVisibleFraction) {
      _visibleSince.putIfAbsent(id, DateTime.now);
      _qualificationTimers.putIfAbsent(
        id,
        () => Timer(_qualifiedVisibilityDuration, () {
          _qualificationTimers.remove(id);
          if (_visibleSince.containsKey(id)) _markRecent(id);
        }),
      );
    } else {
      _qualificationTimers.remove(id)?.cancel();
      unawaited(_flush(id));
    }
  }

  /// Marks explicit feedback immediately so a refresh cannot resurface the
  /// exact post while its Firestore trigger is still being processed.
  void markInteracted(String postId) {
    final id = postId.trim();
    if (id.isEmpty) return;
    _markRecent(id);
  }

  List<String> recentPostIds({int limit = 100}) {
    if (limit <= 0) return const <String>[];
    return _recentPostIds
        .toList(growable: false)
        .reversed
        .take(limit)
        .toList(growable: false);
  }

  /// Flushes visible cards before pull-to-refresh and waits for all exposure
  /// writes already in flight. Local IDs still protect novelty if the network
  /// write takes longer than the bounded wait used by the caller.
  Future<void> flushVisibleAndWait() async {
    final visibleIds = _visibleSince.keys.toList(growable: false);
    final writes = <Future<void>>[];
    for (final postId in visibleIds) {
      _qualificationTimers.remove(postId)?.cancel();
      writes.add(_flush(postId));
    }
    writes.addAll(_pendingWrites);
    if (writes.isNotEmpty) await Future.wait(writes);
  }

  Future<void> _flush(String postId) {
    final startedAt = _visibleSince.remove(postId);
    if (startedAt == null) return Future<void>.value();
    final dwellMs = DateTime.now().difference(startedAt).inMilliseconds;
    if (dwellMs >= 500) _markRecent(postId);

    late final Future<void> write;
    write = _repository
        .recordExposure(postId: postId, dwellMs: dwellMs, source: 'feed')
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Failed to record feed exposure: $error');
        })
        .whenComplete(() => _pendingWrites.remove(write));
    _pendingWrites.add(write);
    return write;
  }

  void _markRecent(String postId) {
    _recentPostIds.remove(postId);
    _recentPostIds.add(postId);
    while (_recentPostIds.length > 200) {
      _recentPostIds.remove(_recentPostIds.first);
    }
  }

  @override
  void onClose() {
    for (final timer in _qualificationTimers.values) {
      timer.cancel();
    }
    _qualificationTimers.clear();
    unawaited(flushVisibleAndWait());
    super.onClose();
  }
}
