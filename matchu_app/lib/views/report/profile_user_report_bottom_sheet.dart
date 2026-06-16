import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/report/user_profile_report_controller.dart';
import 'package:matchu_app/models/user_profile_report_reason.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ProfileUserReportBottomSheet extends StatefulWidget {
  const ProfileUserReportBottomSheet({
    super.key,
    required this.toUid,
    this.reportedUserName = '',
  });

  final String toUid;
  final String reportedUserName;

  @override
  State<ProfileUserReportBottomSheet> createState() =>
      _ProfileUserReportBottomSheetState();
}

class _ProfileUserReportBottomSheetState
    extends State<ProfileUserReportBottomSheet> {
  late final String _controllerTag;
  late final UserProfileReportController _controller;

  @override
  void initState() {
    super.initState();
    _controllerTag =
        'profile-user-report-${widget.toUid}-${identityHashCode(this)}';
    _controller = Get.put(
      UserProfileReportController(
        toUid: widget.toUid,
        reportedUserName: widget.reportedUserName,
      ),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<UserProfileReportController>(tag: _controllerTag)) {
      Get.delete<UserProfileReportController>(tag: _controllerTag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Obx(() {
          final selectedCategory = _controller.selectedCategory.value;
          final selectedReason = _controller.selectedReason.value;
          final requiresCustomReason = _controller.requiresCustomReason;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: SingleChildScrollView(
              key: ValueKey(selectedCategory?.key ?? 'root'),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (selectedCategory != null)
                        IconButton(
                          onPressed: _controller.goBackToCategories,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          selectedCategory == null
                              ? 'Báo cáo người dùng'
                              : selectedCategory.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedCategory == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Chọn nhóm lý do phù hợp nhất.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                    ),
                  if (selectedCategory == null)
                    ..._controller.categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReportCategoryTile(
                          category: category,
                          onTap: () => _controller.openCategory(category),
                        ),
                      ),
                    )
                  else ...[
                    _SectionLabel(label: 'Mục chi tiết'),
                    const SizedBox(height: 12),
                    ...selectedCategory.reasons.map(
                      (reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReportReasonTile(
                          title: reason.title,
                          selected: selectedReason?.key == reason.key,
                          onTap: () => _controller.selectReason(reason),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (requiresCustomReason) ...[
                      _SectionLabel(label: 'Lý do cụ thể'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _controller.customReasonCtrl,
                        maxLines: 3,
                        maxLength: 200,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Nhập lý do khác',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _SectionLabel(label: 'Chi tiết thêm'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mô tả thêm (không bắt buộc)',
                            textAlign: TextAlign.left,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.76,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _controller.descriptionCtrl,
                            maxLines: 4,
                            maxLength: 400,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText:
                                  'Bạn có thể bổ sung bối cảnh để đội ngũ kiểm duyệt xem xét chính xác hơn.',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Obx(
                              () => Text(
                                '${_controller.descriptionText.value.length}/400',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () => ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed:
                              _controller.canSubmit ? _controller.submit : null,
                          child:
                              _controller.isSubmitting.value
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text('Gửi báo cáo'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Hủy'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ReportCategoryTile extends StatelessWidget {
  const _ReportCategoryTile({required this.category, required this.onTap});

  final UserProfileReportCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: colorScheme.error, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  const _ReportReasonTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppTheme.errorColor.withValues(alpha: 0.07)
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected
                    ? AppTheme.errorColor.withValues(alpha: 0.5)
                    : Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.errorColor : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
