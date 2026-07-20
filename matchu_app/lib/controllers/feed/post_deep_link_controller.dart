import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/feed/post_link_parser.dart';
import 'package:matchu_app/services/feed/post_service.dart';

class PostDeepLinkController extends GetxController {
  PostDeepLinkController({
    AppLinks? appLinks,
    PostLinkParser? parser,
    PostService? postService,
    FirebaseAuth? auth,
  }) : _appLinks = appLinks ?? AppLinks(),
       _parser = parser ?? PostLinkParser(),
       _postService = postService ?? PostService(),
       _auth = auth ?? FirebaseAuth.instance;

  final AppLinks _appLinks;
  final PostLinkParser _parser;
  final PostService _postService;
  final FirebaseAuth _auth;

  final RxnString pendingPostId = RxnString();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isOpening = false;
  String? _lastOpenedPostId;
  DateTime? _lastOpenedAt;

  static const Duration _deduplicationWindow = Duration(seconds: 2);

  @override
  void onInit() {
    super.onInit();
    // uriLinkStream includes both cold-start and subsequent links.
    _linkSubscription = _appLinks.uriLinkStream.listen(
      handleUri,
      onError: (_) {},
    );
  }

  void handleUri(Uri uri) {
    final postId = _parser.parsePostId(uri);
    if (postId == null || _wasRecentlyOpened(postId)) return;

    pendingPostId.value = postId;
    unawaited(flushPendingNavigation());
  }

  Future<void> flushPendingNavigation() async {
    final postId = pendingPostId.value?.trim() ?? '';
    if (postId.isEmpty || _isOpening || !_canNavigateNow()) return;

    _isOpening = true;
    try {
      final post = await _postService.fetchPostById(postId);
      if (pendingPostId.value != postId) return;

      pendingPostId.value = null;
      if (post == null) {
        _showUnavailableMessage();
        return;
      }

      _lastOpenedPostId = postId;
      _lastOpenedAt = DateTime.now();
      final arguments = PostDetailRouteArgs(post: post);
      if (Get.currentRoute == AppRouter.postDetail) {
        // Replace the existing detail route so its untagged GetX controller is
        // disposed before the binding creates one for the linked post.
        await Get.offNamed(AppRouter.postDetail, arguments: arguments);
      } else {
        await Get.toNamed(AppRouter.postDetail, arguments: arguments);
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        if (pendingPostId.value == postId) pendingPostId.value = null;
        _showUnavailableMessage();
        return;
      }
      if (pendingPostId.value == postId) _showRetryMessage();
    } catch (_) {
      if (pendingPostId.value == postId) {
        // Keep the link pending so a temporary network error can be retried.
        _showRetryMessage();
      }
    } finally {
      _isOpening = false;
    }
  }

  bool _canNavigateNow() {
    if (_auth.currentUser == null || Get.context == null) return false;

    return !<String>{
      AppRouter.splash,
      AppRouter.welcome,
      AppRouter.login,
      AppRouter.otpLogin,
      AppRouter.register,
      AppRouter.verifyEmail,
      AppRouter.enrollPhone,
      AppRouter.otpEnroll,
      AppRouter.completeProfile,
      AppRouter.forgotPassword,
    }.contains(Get.currentRoute);
  }

  bool _wasRecentlyOpened(String postId) {
    final openedAt = _lastOpenedAt;
    return _lastOpenedPostId == postId &&
        openedAt != null &&
        DateTime.now().difference(openedAt) < _deduplicationWindow;
  }

  void _showUnavailableMessage() {
    Get.snackbar(
      'Bài viết không khả dụng'.tr,
      'Bài viết đã bị xóa hoặc bạn không còn quyền xem.'.tr,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _showRetryMessage() {
    Get.snackbar(
      'Không thể mở bài viết'.tr,
      'Vui lòng kiểm tra kết nối mạng và thử lại.'.tr,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  void onClose() {
    unawaited(_linkSubscription?.cancel());
    super.onClose();
  }
}
