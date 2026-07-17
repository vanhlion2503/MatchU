import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/post_search_result.dart';
import 'package:matchu_app/services/feed/post_search_repository.dart';

enum PostSearchStatus { initial, loading, success, empty, error }

class PostSearchController extends GetxController {
  PostSearchController({PostSearchRepository? repository})
    : _repository = repository ?? PostSearchRepository();

  final PostSearchRepository _repository;
  final TextEditingController searchTextController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final RxList<PostSearchItem> results = <PostSearchItem>[].obs;
  final Rx<PostSearchStatus> status = PostSearchStatus.initial.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxInt totalMatched = 0.obs;
  final RxString submittedQuery = ''.obs;
  final RxnString errorMessage = RxnString();

  int _requestVersion = 0;
  int _nextOffset = 0;

  String get currentUserId => _repository.currentUserId;

  Future<void> submitSearch() async {
    final query = searchTextController.text.trim();
    if (query.isEmpty) {
      errorMessage.value = 'Vui lòng nhập từ khóa cần tìm.';
      status.value = PostSearchStatus.initial;
      return;
    }

    final requestVersion = ++_requestVersion;
    submittedQuery.value = query;
    status.value = PostSearchStatus.loading;
    errorMessage.value = null;
    hasMore.value = false;
    totalMatched.value = 0;
    _nextOffset = 0;
    results.clear();
    searchFocusNode.unfocus();

    try {
      final page = await _repository.search(query: query, offset: 0);
      if (requestVersion != _requestVersion) return;
      results.assignAll(page.items);
      hasMore.value = page.hasMore;
      totalMatched.value = page.totalMatched;
      _nextOffset = page.nextOffset;
      status.value =
          page.items.isEmpty
              ? PostSearchStatus.empty
              : PostSearchStatus.success;
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      errorMessage.value = _mapError(error);
      status.value = PostSearchStatus.error;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || submittedQuery.isEmpty) return;

    final requestVersion = _requestVersion;
    isLoadingMore.value = true;
    try {
      final page = await _repository.search(
        query: submittedQuery.value,
        offset: _nextOffset,
      );
      if (requestVersion != _requestVersion) return;
      final existingIds = results.map((item) => item.post.postId).toSet();
      results.addAll(
        page.items.where((item) => existingIds.add(item.post.postId)),
      );
      hasMore.value = page.hasMore;
      totalMatched.value = page.totalMatched;
      _nextOffset = page.nextOffset;
    } catch (error) {
      Get.snackbar(
        'Lỗi',
        _mapError(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (requestVersion == _requestVersion) isLoadingMore.value = false;
    }
  }

  Future<void> toggleLike(String postId) async {
    final index = results.indexWhere((item) => item.post.postId == postId);
    if (index < 0 || results[index].post.isLikePending) return;

    final original = results[index];
    final nextLiked = !original.post.isLiked;
    _replacePost(
      original.post.copyWith(
        isLiked: nextLiked,
        isLikePending: true,
        stats: original.post.stats.copyWith(
          likeCount: (original.post.stats.likeCount + (nextLiked ? 1 : -1))
              .clamp(0, 1 << 31),
        ),
      ),
    );

    try {
      await _repository.setPostLiked(postId, isLiked: nextLiked);
      final current = _findPost(postId);
      if (current != null) {
        _replacePost(current.copyWith(isLikePending: false));
      }
    } catch (error) {
      _replacePost(original.post);
      Get.snackbar(
        'Lỗi',
        _mapError(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> toggleSave(String postId) async {
    final current = _findPost(postId);
    if (current == null || current.isSavePending) return;
    final nextSaved = !current.isSaved;
    _replacePost(current.copyWith(isSaved: nextSaved, isSavePending: true));
    try {
      await _repository.setPostSaved(postId, isSaved: nextSaved);
      final latest = _findPost(postId);
      if (latest != null) _replacePost(latest.copyWith(isSavePending: false));
    } catch (error) {
      _replacePost(current);
      Get.snackbar(
        'Lỗi',
        _mapError(error),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void removeAuthor(String authorId) {
    final normalized = authorId.trim();
    if (normalized.isEmpty) return;
    results.removeWhere((item) => item.post.authorId.trim() == normalized);
    if (results.isEmpty) status.value = PostSearchStatus.empty;
  }

  PostModel? _findPost(String postId) {
    final index = results.indexWhere((item) => item.post.postId == postId);
    return index < 0 ? null : results[index].post;
  }

  void _replacePost(PostModel post) {
    final index = results.indexWhere((item) => item.post.postId == post.postId);
    if (index < 0) return;
    results[index] = results[index].copyWith(post: post);
  }

  String _mapError(Object error) {
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'unauthenticated' =>
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        'invalid-argument' => 'Từ khóa tìm kiếm không hợp lệ.',
        _ => 'Không thể tìm kiếm bài viết lúc này. Vui lòng thử lại.',
      };
    }
    return 'Không thể tìm kiếm bài viết lúc này. Vui lòng thử lại.';
  }

  @override
  void onClose() {
    searchTextController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }
}
