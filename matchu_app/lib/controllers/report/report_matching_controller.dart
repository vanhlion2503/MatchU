import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/models/report_reason.dart';
import 'package:matchu_app/services/report/report_matching_service.dart';
import 'package:matchu_app/models/user_report_matching_model.dart';

class ReportMatchingController extends GetxController {
  final String roomId;
  final String toUid;

  ReportMatchingController({required this.roomId, required this.toUid});

  // ===== STATE =====
  final selectedReasonKey = RxnString();
  final descriptionCtrl = TextEditingController();
  final isSubmitting = false.obs;

  // ===== REASONS =====
  final reasons = const [
    ReportReason(
      key: "phamcam",
      title: "Nội dung phản cảm",
      icon: Iconsax.message_text,
    ),
    ReportReason(
      key: "quayroi",
      title: "Quấy rối hoặc bắt nạt",
      icon: Iconsax.forbidden,
    ),
    ReportReason(
      key: "giamao",
      title: "Giả mạo người khác",
      icon: Iconsax.user_remove,
    ),
    ReportReason(
      key: "spam",
      title: "Spam tin nhắn",
      icon: Iconsax.message_remove,
    ),
    ReportReason(key: "khac", title: "Lý do khác", icon: Iconsax.more),
  ];

  // ===== ACTIONS =====
  void select(String key) {
    selectedReasonKey.value = key;
  }

  Future<void> submit() async {
    if (selectedReasonKey.value == null) return;
    if (isSubmitting.value) return; // 🔒 chặn double tap

    isSubmitting.value = true;

    try {
      final myUid = Get.find<AuthController>().user!.uid;

      await ReportMatchingService.submitReport(
        UserReportMatchingModel(
          roomId: roomId,
          fromUid: myUid,
          toUid: toUid,
          reason: selectedReasonKey.value!, // ✅ FIX
          description: descriptionCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
      );

      Get.back();

      Get.snackbar(
        "Đã gửi báo cáo",
        "Cảm ơn bạn đã giúp MatchU an toàn hơn",
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        "Lỗi",
        "Không thể gửi báo cáo. Vui lòng thử lại.",
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    descriptionCtrl.dispose();
    super.onClose();
  }
}
