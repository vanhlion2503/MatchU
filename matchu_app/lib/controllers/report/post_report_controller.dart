import 'dart:io';

import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/post_report_model.dart';
import 'package:matchu_app/models/post_report_reason.dart';
import 'package:matchu_app/services/report/post_report_service.dart';

class PostReportController extends GetxController {
  PostReportController({required this.post});

  static const int maxEvidenceImages = 3;

  final PostModel post;
  final ImagePicker _picker = ImagePicker();

  final List<PostReportCategory> categories = postReportCategories;

  final selectedCategory = Rxn<PostReportCategory>();
  final selectedReason = Rxn<PostReportReason>();
  final isSubmitting = false.obs;
  final isPickingImages = false.obs;
  final customReasonText = ''.obs;
  final descriptionText = ''.obs;
  final RxList<File> evidenceImages = <File>[].obs;

  final customReasonCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  bool get requiresCustomReason =>
      selectedReason.value?.requiresCustomReason == true;

  String get reportedAuthorName {
    final name = post.author.name.trim();
    if (name.isNotEmpty) return name;

    final nickname = post.author.nickname.trim();
    if (nickname.isNotEmpty) return nickname;

    return 'người dùng này';
  }

  String get postPreviewText {
    final content = post.content.trim();
    if (content.isNotEmpty) return content;
    if (post.media.isNotEmpty) {
      return 'Bài viết có ${post.media.length} tệp đính kèm.';
    }
    return 'Bài viết này không có nội dung văn bản.';
  }

  bool get canSubmit {
    if (isSubmitting.value) return false;
    if (selectedCategory.value == null || selectedReason.value == null) {
      return false;
    }

    if (requiresCustomReason && customReasonText.value.trim().isEmpty) {
      return false;
    }

    return true;
  }

  @override
  void onInit() {
    super.onInit();
    customReasonCtrl.addListener(_syncCustomReasonText);
    descriptionCtrl.addListener(_syncDescriptionText);
  }

  void openCategory(PostReportCategory category) {
    selectedCategory.value = category;
    selectedReason.value = null;
    customReasonCtrl.clear();
    descriptionCtrl.clear();
    evidenceImages.clear();
  }

  void goBackToCategories() {
    selectedCategory.value = null;
    selectedReason.value = null;
    customReasonCtrl.clear();
    descriptionCtrl.clear();
    evidenceImages.clear();
  }

  void selectReason(PostReportReason reason) {
    selectedReason.value = reason;
    if (!reason.requiresCustomReason) {
      customReasonCtrl.clear();
    }
  }

  Future<void> pickEvidenceImages() async {
    if (isPickingImages.value || isSubmitting.value) return;

    final remainingSlots = maxEvidenceImages - evidenceImages.length;
    if (remainingSlots <= 0) {
      _showError('Bạn chỉ có thể đính kèm tối đa $maxEvidenceImages ảnh.');
      return;
    }

    try {
      isPickingImages.value = true;
      final picked = await _picker.pickMultiImage(imageQuality: 88);
      if (picked.isEmpty) return;

      final limited = picked.take(remainingSlots).toList(growable: false);
      evidenceImages.addAll(limited.map((file) => File(file.path)));

      if (picked.length > remainingSlots) {
        Get.snackbar(
          PostTranslationKeys.imageLimit.tr,
          PostTranslationKeys.imageLimitMessage.trParams({
            'remaining': '$remainingSlots',
            'max': '$maxEvidenceImages',
          }),
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (_) {
      _showError('Không thể chọn ảnh lúc này.');
    } finally {
      isPickingImages.value = false;
    }
  }

  void removeEvidenceImageAt(int index) {
    if (index < 0 || index >= evidenceImages.length) return;
    evidenceImages.removeAt(index);
  }

  Future<void> submit() async {
    final category = selectedCategory.value;
    final reason = selectedReason.value;

    if (category == null || reason == null) {
      _showError('Vui lòng chọn lý do báo cáo.');
      return;
    }

    final myUid = Get.find<AuthController>().user?.uid.trim() ?? '';
    if (myUid.isEmpty) {
      _showError('Phiên đăng nhập đã hết hạn. Vui lòng thử lại.');
      return;
    }

    final authorUid = post.authorId.trim();
    if (authorUid.isEmpty) {
      _showError('Không tìm thấy tác giả bài viết.');
      return;
    }

    final customReason = customReasonCtrl.text.trim();
    if (reason.requiresCustomReason && customReason.isEmpty) {
      _showError('Vui lòng nhập lý do cụ thể.');
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;

    try {
      await PostReportService.submitReport(
        PostReportModel(
          fromUid: myUid,
          toUid: authorUid,
          postId: post.postId,
          postType: post.postType.firestoreValue,
          postAuthorName: post.author.name.trim(),
          postAuthorNickname: post.author.nickname.trim(),
          postContentPreview: post.content.trim(),
          postMediaUrls: post.media
              .map((item) => item.url.trim())
              .where((url) => url.isNotEmpty)
              .toList(growable: false),
          categoryKey: category.key,
          categoryTitle: category.title,
          reasonKey: reason.key,
          reasonTitle: reason.title,
          customReason: customReason,
          description: descriptionCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
        evidenceImages: evidenceImages.toList(growable: false),
      );

      Get.back(result: true);
      Get.snackbar(
        'Đã gửi báo cáo'.tr,
        PostTranslationKeys.reportSentMessage.trParams({
          'author': reportedAuthorName,
        }),
        snackPosition: SnackPosition.TOP,
      );
    } catch (error) {
      _showError(_readableError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  void _syncCustomReasonText() {
    customReasonText.value = customReasonCtrl.text;
  }

  void _syncDescriptionText() {
    descriptionText.value = descriptionCtrl.text;
  }

  String _readableError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return 'Không thể gửi báo cáo. Vui lòng thử lại.';
  }

  void _showError(String message) {
    Get.snackbar(
      PostTranslationKeys.error.tr,
      postTr(message),
      snackPosition: SnackPosition.TOP,
    );
  }

  @override
  void onClose() {
    customReasonCtrl
      ..removeListener(_syncCustomReasonText)
      ..dispose();
    descriptionCtrl
      ..removeListener(_syncDescriptionText)
      ..dispose();
    super.onClose();
  }
}
