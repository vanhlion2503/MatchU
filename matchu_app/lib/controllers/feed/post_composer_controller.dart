import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/post_media_draft.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';

class PostComposerController extends GetxController {
  PostComposerController({PostService? service})
    : _service = service ?? PostService();

  static const int maxMediaItems = 6;

  final PostService _service;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController contentController = TextEditingController();
  final TextEditingController tagInputController = TextEditingController();

  final RxList<PostMediaDraft> mediaDrafts = <PostMediaDraft>[].obs;
  final RxList<String> tags = <String>[].obs;
  final RxInt contentLength = 0.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isPickingMedia = false.obs;
  final RxBool isPublic = true.obs;
  final RxBool isTagEditorVisible = false.obs;

  int get remainingCharacters =>
      PostService.maxContentLength - contentLength.value;

  bool get canSubmit =>
      !isSubmitting.value &&
      (contentLength.value > 0 || mediaDrafts.isNotEmpty) &&
      contentLength.value <= PostService.maxContentLength;

  @override
  void onInit() {
    super.onInit();
    contentController.addListener(_handleContentChanged);
    tagInputController.addListener(_handleTagInputChanged);
    _handleContentChanged();
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

  void removeTag(String tag) {
    tags.remove(tag);
  }

  void commitPendingTag() {
    _appendTagsFromRaw(tagInputController.text, clearInput: true);
  }

  void showTagEditor() {
    isTagEditorVisible.value = true;
  }

  Future<PostModel?> submit() async {
    if (isSubmitting.value) return null;

    commitPendingTag();
    final content = contentController.text.trim();
    if (content.isEmpty && mediaDrafts.isEmpty) {
      _showError('Bài viết cần có nội dung hoặc tệp đính kèm.');
      return null;
    }

    if (content.length > PostService.maxContentLength) {
      _showError('Nội dung bài viết không được vượt quá 300 ký tự.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final post = await _service.createPost(
        content: content,
        mediaDrafts: mediaDrafts.toList(growable: false),
        tags: tags.toList(growable: false),
        isPublic: isPublic.value,
      );
      return post;
    } catch (error) {
      _showError(error.toString());
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  void _appendMedia(List<PostMediaDraft> drafts) {
    final next = [...mediaDrafts, ...drafts];
    if (next.length <= maxMediaItems) {
      mediaDrafts.assignAll(next);
      return;
    }

    mediaDrafts.assignAll(next.take(maxMediaItems).toList(growable: false));
    Get.snackbar(
      'Thông báo',
      'Chỉ có thể đăng tối đa $maxMediaItems tệp đính kèm cho mỗi bài viết.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
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
}
