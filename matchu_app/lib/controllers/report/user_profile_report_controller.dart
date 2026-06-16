import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/user_profile_report_model.dart';
import 'package:matchu_app/models/user_profile_report_reason.dart';
import 'package:matchu_app/services/report/user_profile_report_service.dart';

class UserProfileReportController extends GetxController {
  UserProfileReportController({
    required this.toUid,
    this.reportedUserName = '',
  });

  final String toUid;
  final String reportedUserName;

  final List<UserProfileReportCategory> categories =
      userProfileReportCategories;

  final selectedCategory = Rxn<UserProfileReportCategory>();
  final selectedReason = Rxn<UserProfileReportReason>();
  final isSubmitting = false.obs;
  final customReasonText = ''.obs;
  final descriptionText = ''.obs;

  final customReasonCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  bool get requiresCustomReason =>
      selectedReason.value?.requiresCustomReason == true;

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

  void openCategory(UserProfileReportCategory category) {
    selectedCategory.value = category;
    selectedReason.value = null;
    customReasonCtrl.clear();
    descriptionCtrl.clear();
  }

  void goBackToCategories() {
    selectedCategory.value = null;
    selectedReason.value = null;
    customReasonCtrl.clear();
    descriptionCtrl.clear();
  }

  void selectReason(UserProfileReportReason reason) {
    selectedReason.value = reason;
    if (!reason.requiresCustomReason) {
      customReasonCtrl.clear();
    }
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

    final customReason = customReasonCtrl.text.trim();
    if (reason.requiresCustomReason && customReason.isEmpty) {
      _showError('Vui lòng nhập lý do cụ thể.');
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;

    try {
      await UserProfileReportService.submitReport(
        UserProfileReportModel(
          fromUid: myUid,
          toUid: toUid,
          categoryKey: category.key,
          categoryTitle: category.title,
          reasonKey: reason.key,
          reasonTitle: reason.title,
          customReason: customReason,
          description: descriptionCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
      );

      Get.back(result: true);
      Get.snackbar(
        'Đã gửi báo cáo',
        reportedUserName.trim().isEmpty
            ? 'Chúng tôi sẽ xem xét báo cáo của bạn.'
            : 'Chúng tôi sẽ xem xét tài khoản $reportedUserName.',
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
    Get.snackbar('Lỗi', message, snackPosition: SnackPosition.TOP);
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
