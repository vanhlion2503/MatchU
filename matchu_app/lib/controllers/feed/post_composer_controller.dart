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
  final TextEditingController tagsController = TextEditingController();

  final RxList<PostMediaDraft> mediaDrafts = <PostMediaDraft>[].obs;
  final RxInt contentLength = 0.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isPickingMedia = false.obs;
  final RxBool isPublic = true.obs;

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
      _showError('Khong the chon anh luc nay: $error');
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
      _showError('Khong the chon video luc nay: $error');
    } finally {
      isPickingMedia.value = false;
    }
  }

  void removeMedia(PostMediaDraft draft) {
    mediaDrafts.remove(draft);
  }

  Future<PostModel?> submit() async {
    if (isSubmitting.value) return null;

    final content = contentController.text.trim();
    if (content.isEmpty && mediaDrafts.isEmpty) {
      _showError('Bai viet can co noi dung hoac media.');
      return null;
    }

    if (content.length > PostService.maxContentLength) {
      _showError('Noi dung bai viet khong duoc vuot qua 300 ky tu.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final post = await _service.createPost(
        content: content,
        mediaDrafts: mediaDrafts.toList(growable: false),
        tags: _parseTags(tagsController.text),
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
      'Thong bao',
      'Chi co the dang toi da $maxMediaItems tep media cho moi bai viet.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  List<String> _parseTags(String rawText) {
    return rawText
        .split(RegExp(r'[\s,]+'))
        .map((tag) => tag.replaceAll('#', '').trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  void _showError(String message) {
    Get.snackbar(
      'Loi',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  void onClose() {
    contentController.removeListener(_handleContentChanged);
    contentController.dispose();
    tagsController.dispose();
    super.onClose();
  }

  void _handleContentChanged() {
    contentLength.value = contentController.text.trim().length;
  }
}
