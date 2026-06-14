import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/post_media_draft.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';

class PostComposerController extends GetxController {
  PostComposerController({
    this.quotedPost,
    this.editingPost,
    PostService? service,
  }) : assert(quotedPost == null || editingPost == null),
       _service = service ?? PostService();

  static const int maxMediaItems = PostService.maxMediaItems;

  final PostService _service;
  final ImagePicker _picker = ImagePicker();
  final PostModel? quotedPost;
  final PostModel? editingPost;

  final TextEditingController contentController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();

  final RxList<MediaModel> existingMedia = <MediaModel>[].obs;
  final RxList<PostMediaDraft> mediaDrafts = <PostMediaDraft>[].obs;
  final RxList<String> tags = <String>[].obs;
  final RxInt contentLength = 0.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isPickingMedia = false.obs;
  final Rx<PostVisibility> visibility = PostVisibility.public.obs;
  final RxBool isTagEditorVisible = false.obs;

  bool get isEditComposer => editingPost != null;
  bool get isQuoteComposer => quotedPost != null;

  PostModel? get previewReferencePost {
    if (quotedPost != null) return quotedPost;
    final post = editingPost;
    if (post == null || post.referencePost == null) return null;
    return post;
  }

  int get remainingCharacters =>
      PostService.maxContentLength - contentLength.value;

  bool get canSubmit {
    final hasEditableBody =
        contentLength.value > 0 ||
        existingMedia.isNotEmpty ||
        mediaDrafts.isNotEmpty;
    final canSubmitEmptyBody =
        isQuoteComposer || editingPost?.postType.requiresReference == true;

    return !isSubmitting.value &&
        (canSubmitEmptyBody || hasEditableBody) &&
        contentLength.value <= PostService.maxContentLength;
  }

  @override
  void onInit() {
    super.onInit();
    _seedEditState();
    contentController.addListener(_handleContentChanged);
    tagInputController.addListener(_handleTagInputChanged);
    _handleContentChanged();
    if (!isEditComposer) {
      _setSafeDefaultVisibilityForQuote();
    }
  }

  Future<void> pickImages() async {
    if (isPickingMedia.value) return;

    try {
      isPickingMedia.value = true;
      final picked = await _picker.pickMultiImage(imageQuality: 92);
      if (picked.isEmpty) return;

      final drafts = picked
          .map(
            (file) => PostMediaDraft(
              file: File(file.path),
              type: PostMediaType.image,
              fileName: file.name,
            ),
          )
          .toList(growable: false);

      _appendMedia(drafts);
    } catch (error) {
      _showError('Không thể chọn ảnh lúc này: $error');
    } finally {
      isPickingMedia.value = false;
    }
  }

  Future<void> pickVideo() async {
    if (isPickingMedia.value) return;

    try {
      isPickingMedia.value = true;
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      _appendMedia([
        PostMediaDraft(
          file: File(picked.path),
          type: PostMediaType.video,
          fileName: picked.name,
        ),
      ]);
    } catch (error) {
      _showError('Không thể chọn video lúc này: $error');
    } finally {
      isPickingMedia.value = false;
    }
  }

  void removeMedia(PostMediaDraft draft) {
    mediaDrafts.remove(draft);
  }

  void removeExistingMedia(MediaModel media) {
    existingMedia.remove(media);
  }

  void removeTag(String tag) {
    tags.remove(tag);
  }

  void commitPendingTag() {
    _appendTagsFromRaw(tagInputController.text, clearInput: true);
  }

  void showTagEditor() {
    isTagEditorVisible.value = true;
  }

  void setVisibility(PostVisibility nextVisibility) {
    visibility.value = nextVisibility;
  }

  Future<PostModel?> submit() async {
    if (isSubmitting.value) return null;

    commitPendingTag();
    final content = contentController.text.trim();
    final hasEditableBody =
        content.isNotEmpty ||
        existingMedia.isNotEmpty ||
        mediaDrafts.isNotEmpty;
    final canSubmitEmptyBody =
        isQuoteComposer || editingPost?.postType.requiresReference == true;

    if (!canSubmitEmptyBody && !hasEditableBody) {
      _showError('Bài viết cần có nội dung hoặc tệp đính kèm.');
      return null;
    }

    if (content.length > PostService.maxContentLength) {
      _showError('Nội dung bài viết không được vượt quá 300 ký tự.');
      return null;
    }

    isSubmitting.value = true;
    try {
      return await _submitResolvedPost(content);
    } catch (error) {
      _showError(_humanizeError(error));
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  void _appendMedia(List<PostMediaDraft> drafts) {
    final availableDraftSlots = maxMediaItems - existingMedia.length;
    if (availableDraftSlots <= 0) {
      _showMaxMediaNotice();
      return;
    }

    final next = [...mediaDrafts, ...drafts];
    if (next.length <= availableDraftSlots) {
      mediaDrafts.assignAll(next);
      return;
    }

    mediaDrafts.assignAll(
      next.take(availableDraftSlots).toList(growable: false),
    );
    _showMaxMediaNotice();
  }

  void _appendTagsFromRaw(String rawText, {required bool clearInput}) {
    final parsedTags = _parseTags(rawText);
    if (parsedTags.isEmpty) {
      if (clearInput) {
        tagInputController.clear();
      }
      return;
    }

    final current = tags.toSet();
    final next = [...tags];

    for (final tag in parsedTags) {
      if (current.contains(tag)) continue;
      current.add(tag);
      next.add(tag);
    }

    tags.assignAll(next);
    if (clearInput) {
      tagInputController.clear();
    }
  }

  List<String> _parseTags(String rawText) {
    return rawText
        .split(RegExp(r'[\s,]+'))
        .map((tag) => tag.replaceAll('#', '').trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  void _handleTagInputChanged() {
    final currentValue = tagInputController.text;
    if (!RegExp(r'[\s,]+').hasMatch(currentValue)) return;
    _appendTagsFromRaw(currentValue, clearInput: true);
  }

  Future<PostModel> _submitResolvedPost(String content) {
    final postBeingEdited = editingPost;
    if (postBeingEdited != null) {
      return _service.updatePost(
        post: postBeingEdited,
        content: content,
        retainedMedia: existingMedia.toList(growable: false),
        newMediaDrafts: mediaDrafts.toList(growable: false),
        tags: tags.toList(growable: false),
        visibility: visibility.value,
      );
    }

    final sourcePost = quotedPost;
    if (sourcePost != null) {
      return _service.createQuotePost(
        content: content,
        mediaDrafts: mediaDrafts.toList(growable: false),
        tags: tags.toList(growable: false),
        sourcePost: sourcePost,
        visibility: visibility.value,
      );
    }

    return _service.createPost(
      content: content,
      mediaDrafts: mediaDrafts.toList(growable: false),
      tags: tags.toList(growable: false),
      visibility: visibility.value,
    );
  }

  void _seedEditState() {
    final post = editingPost;
    if (post == null) return;

    contentController.text = post.content;
    tags.assignAll(post.tags);
    visibility.value = post.visibility;
    existingMedia.assignAll(post.media);
    isTagEditorVisible.value = post.tags.isNotEmpty;
  }

  void _showMaxMediaNotice() {
    Get.snackbar(
      'Thông báo',
      'Chỉ có thể đăng tối đa $maxMediaItems tệp đính kèm cho mỗi bài viết.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  String _humanizeError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return error.toString();
  }

  void _showError(String message) {
    Get.snackbar(
      'Lỗi',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  void onClose() {
    contentController.removeListener(_handleContentChanged);
    tagInputController.removeListener(_handleTagInputChanged);
    contentController.dispose();
    tagInputController.dispose();
    super.onClose();
  }

  void _handleContentChanged() {
    contentLength.value = contentController.text.trim().length;
  }

  void _setSafeDefaultVisibilityForQuote() {
    final sourcePost = quotedPost;
    if (sourcePost == null || sourcePost.isPublic) return;
    if (sourcePost.authorId.trim() == _service.uid.trim()) return;
    visibility.value = PostVisibility.private;
  }
}
