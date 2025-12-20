import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/controllers/report/report_matching_controller.dart';
import 'package:matchu_app/views/report/report_reason_tile.dart';

class ReportBottomSheet extends StatelessWidget {
  final String roomId;
  final String toUid;

  const ReportBottomSheet({
    super.key,
    required this.roomId,
    required this.toUid,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ReportMatchingController(roomId: roomId, toUid: toUid),
    );

    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,

        // 🎨 BACKGROUND + BO GÓC
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),

        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== DRAG HANDLE =====
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkBorder 
                            : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ===== HEADER =====
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Báo cáo vi phạm",
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: Get.back,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Text(
                "Lý do báo cáo",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 16),

              // ===== REASONS =====
              Obx(() => Column(
                    children: controller.reasons.map((r) {
                      final selected =
                          controller.selectedReasonKey.value == r.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReportReasonTile(
                          reason: r,
                          selected: selected,
                          onTap: () => controller.select(r.key),
                        ),
                      );
                    }).toList(),
                  )),

              const SizedBox(height: 16),

              // ===== DESCRIPTION =====
              Text(
                "Chi tiết thêm",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: controller.descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      "Hãy mô tả chi tiết vấn đề bạn gặp phải để chúng tôi hỗ trợ tốt hơn...",
                ),
              ),

              const SizedBox(height: 20),

              // ===== SUBMIT =====
              Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                      ),
                      onPressed: controller.selectedReasonKey.value == null
                          ? null
                          : controller.submit,
                      child: const Text("🚩 Gửi báo cáo"),
                    ),
                  )),

              const SizedBox(height: 12),

              // ===== CANCEL =====
              Center(
                child: TextButton(
                  onPressed: Get.back,
                  child: const Text("Hủy bỏ"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
