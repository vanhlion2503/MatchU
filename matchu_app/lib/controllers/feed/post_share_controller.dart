import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/repositories/feed/post_share_repository.dart';
import 'package:matchu_app/repositories/feed/post_share_metrics_repository.dart';
import 'package:matchu_app/controllers/feed/post_share_sync.dart';
import 'package:matchu_app/services/feed/post_share_service.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:uuid/uuid.dart';

class PostShareController extends GetxController {
  PostShareController({
    PostShareService? service,
    PostShareMetricsRepository? metricsRepository,
    Uuid? uuid,
  }) : _service = service ?? PostShareService(),
       _metricsRepository =
           metricsRepository ?? FirebasePostShareMetricsRepository(),
       _uuid = uuid ?? const Uuid();

  final PostShareService _service;
  final PostShareMetricsRepository _metricsRepository;
  final Uuid _uuid;
  final RxSet<String> sharingPostIds = <String>{}.obs;

  bool isSharing(String postId) => sharingPostIds.contains(postId.trim());

  Future<void> sharePost(PostModel post, {Rect? sharePositionOrigin}) async {
    final operationId = post.postId.trim();
    if (operationId.isEmpty || isSharing(operationId)) return;

    sharingPostIds.add(operationId);
    try {
      final outcome = await _service.share(
        post,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (outcome.status == PostNativeShareStatus.success) {
        await _recordShare(
          sourcePost: post,
          targetPostId: outcome.payload.postId,
          method: 'native',
        );
      } else if (outcome.status == PostNativeShareStatus.unavailable) {
        _showMessage('Thiết bị hiện không hỗ trợ chia sẻ bài viết.');
      }
    } on PostShareException catch (error) {
      _showMessage(error.message);
    } catch (error, stackTrace) {
      debugPrint('Failed to open native post share: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Không thể chia sẻ bài viết lúc này. Vui lòng thử lại.');
    } finally {
      sharingPostIds.remove(operationId);
    }
  }

  Future<void> copyPostLink(PostModel post) async {
    try {
      final payload = await _service.copyLink(post);
      _showMessage('Đã sao chép liên kết bài viết.');
      await _recordShare(
        sourcePost: post,
        targetPostId: payload.postId,
        method: 'copy',
      );
    } on PostShareException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Không thể sao chép liên kết bài viết.');
    }
  }

  bool canShare(PostModel post) {
    try {
      _service.buildPayload(post);
      return true;
    } on PostShareException catch (error) {
      _showMessage(error.message);
      return false;
    }
  }

  Future<void> _recordShare({
    required PostModel sourcePost,
    required String targetPostId,
    required String method,
  }) async {
    try {
      final result = await _metricsRepository.recordShare(
        postId: targetPostId,
        eventId: _uuid.v4(),
        method: method,
      );
      PostShareSync.applyCount(
        sourcePost: sourcePost,
        targetPostId: targetPostId,
        externalShareCount: result.externalShareCount,
      );
    } catch (error) {
      // Sharing has already succeeded. A metrics outage must not turn it into
      // a user-facing failure; the next post refresh will reconcile the count.
      debugPrint('Failed to record post share: $error');
    }
  }

  static Rect? shareOriginFromContext(BuildContext? context) {
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _showMessage(String message) {
    Get.snackbar(
      PostTranslationKeys.notice.tr,
      message.tr,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}
