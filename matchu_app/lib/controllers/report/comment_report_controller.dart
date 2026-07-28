import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/comment_report_model.dart';
import 'package:matchu_app/models/feed/post_comment_model.dart';
import 'package:matchu_app/models/post_report_reason.dart';
import 'package:matchu_app/services/report/comment_report_service.dart';
import 'package:matchu_app/translations/post_translations.dart';

class CommentReportController extends GetxController {
  CommentReportController({
    required this.postId,
    required this.comment,
    CommentReportService? service,
  }) : _service = service ?? CommentReportService();

  final String postId;
  final PostCommentModel comment;
  final CommentReportService _service;

  final List<PostReportCategory> categories = postReportCategories;
  final selectedCategory = Rxn<PostReportCategory>();
  final selectedReason = Rxn<PostReportReason>();
  final isSubmitting = false.obs;
  final customReasonText = ''.obs;
  final descriptionText = ''.obs;
  final customReasonController = TextEditingController();
  final descriptionController = TextEditingController();

  bool get requiresCustomReason =>
      selectedReason.value?.requiresCustomReason == true;

  bool get canSubmit =>
      !isSubmitting.value &&
      selectedCategory.value != null &&
      selectedReason.value != null &&
      (!requiresCustomReason || customReasonText.value.trim().isNotEmpty);

  String get authorName {
    final name = comment.author?.displayName.trim() ?? '';
    if (name.isNotEmpty) return name;
    final nickname = comment.author?.nickname.trim() ?? '';
    return nickname.isNotEmpty ? nickname : 'người dùng này';
  }

  String get preview {
    if (comment.content.trim().isNotEmpty) return comment.content.trim();
    if (comment.hasImage) return 'Bình luận bằng hình ảnh';
    if (comment.hasVoice) return 'Bình luận bằng ghi âm';
    return 'Bình luận không có nội dung văn bản';
  }

  @override
  void onInit() {
    super.onInit();
    customReasonController.addListener(_syncCustomReason);
    descriptionController.addListener(_syncDescription);
  }

  void openCategory(PostReportCategory category) {
    selectedCategory.value = category;
    selectedReason.value = null;
    customReasonController.clear();
    descriptionController.clear();
  }

  void goBackToCategories() {
    selectedCategory.value = null;
    selectedReason.value = null;
    customReasonController.clear();
    descriptionController.clear();
  }

  void selectReason(PostReportReason reason) {
    selectedReason.value = reason;
    if (!reason.requiresCustomReason) customReasonController.clear();
  }

  Future<void> submit() async {
    final category = selectedCategory.value;
    final reason = selectedReason.value;
    if (category == null || reason == null || isSubmitting.value) return;

    final currentUid = Get.find<AuthController>().user?.uid.trim() ?? '';
    if (currentUid.isEmpty) {
      _showError('Phiên đăng nhập đã hết hạn. Vui lòng thử lại.');
      return;
    }

    final customReason = customReasonController.text.trim();
    if (reason.requiresCustomReason && customReason.isEmpty) {
      _showError('Vui lòng nhập lý do cụ thể.');
      return;
    }

    isSubmitting.value = true;
    try {
      await _service.submitReport(
        CommentReportModel(
          fromUid: currentUid,
          toUid: comment.userId.trim(),
          postId: postId.trim(),
          commentId: comment.commentId.trim(),
          parentId: comment.parentId,
          commentContentPreview: comment.content.trim(),
          commentImageUrl: comment.imageUrl.trim(),
          commentVoiceUrl: comment.voiceUrl.trim(),
          commentAuthorName: comment.author?.displayName.trim() ?? '',
          commentAuthorNickname: comment.author?.nickname.trim() ?? '',
          categoryKey: category.key,
          categoryTitle: category.title,
          reasonKey: reason.key,
          reasonTitle: reason.title,
          customReason: customReason,
          description: descriptionController.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      Get.back(result: true);
      Get.snackbar(
        'Đã gửi báo cáo',
        'Báo cáo bình luận của $authorName đã được gửi để xem xét.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (error) {
      _showError(
        error is StateError
            ? error.message.toString()
            : 'Không thể gửi báo cáo. Vui lòng thử lại.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  void _syncCustomReason() {
    customReasonText.value = customReasonController.text;
  }

  void _syncDescription() {
    descriptionText.value = descriptionController.text;
  }

  void _showError(String message) {
    Get.snackbar(
      PostTranslationKeys.error.tr,
      message,
      snackPosition: SnackPosition.TOP,
    );
  }

  @override
  void onClose() {
    customReasonController
      ..removeListener(_syncCustomReason)
      ..dispose();
    descriptionController
      ..removeListener(_syncDescription)
      ..dispose();
    super.onClose();
  }
}
