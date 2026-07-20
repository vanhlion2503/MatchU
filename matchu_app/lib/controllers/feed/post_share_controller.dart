import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/repositories/feed/post_share_repository.dart';
import 'package:matchu_app/services/feed/post_share_service.dart';
import 'package:matchu_app/translations/post_translations.dart';

class PostShareController extends GetxController {
  PostShareController({PostShareService? service})
    : _service = service ?? PostShareService();

  final PostShareService _service;
  final RxSet<String> sharingPostIds = <String>{}.obs;

  bool isSharing(String postId) => sharingPostIds.contains(postId.trim());

  Future<void> sharePost(PostModel post, {Rect? sharePositionOrigin}) async {
    final operationId = post.postId.trim();
    if (operationId.isEmpty || isSharing(operationId)) return;

    sharingPostIds.add(operationId);
    try {
      final status = await _service.share(
        post,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (status == PostNativeShareStatus.unavailable) {
        _showMessage('Thiết bị hiện không hỗ trợ chia sẻ bài viết.');
      }
    } on PostShareException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Không thể chia sẻ bài viết lúc này. Vui lòng thử lại.');
    } finally {
      sharingPostIds.remove(operationId);
    }
  }

  Future<void> copyPostLink(PostModel post) async {
    try {
      await _service.copyLink(post);
      _showMessage('Đã sao chép liên kết bài viết.');
    } on PostShareException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Không thể sao chép liên kết bài viết.');
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
