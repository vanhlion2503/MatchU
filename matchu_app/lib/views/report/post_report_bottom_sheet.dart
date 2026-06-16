import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/report/post_report_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/report/report_form_widgets.dart';

class PostReportBottomSheet extends StatefulWidget {
  const PostReportBottomSheet({super.key, required this.post});

  final PostModel post;

  static Future<bool?> show({required PostModel post}) {
    return Get.bottomSheet<bool>(
      PostReportBottomSheet(post: post),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<PostReportBottomSheet> createState() => _PostReportBottomSheetState();
}

class _PostReportBottomSheetState extends State<PostReportBottomSheet> {
  late final String _controllerTag;
  late final PostReportController _controller;

  @override
  void initState() {
    super.initState();
    _controllerTag =
        'post-report-${widget.post.postId}-${identityHashCode(this)}';
    _controller = Get.put(
      PostReportController(post: widget.post),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<PostReportController>(tag: _controllerTag)) {
      Get.delete<PostReportController>(tag: _controllerTag);
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
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
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
                              ? 'Báo cáo bài viết'
                              : selectedCategory.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: Get.back,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedCategory == null) ...[
                    Text(
                      'Bài viết của ${_controller.reportedAuthorName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.brightness == Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                        ),
                      ),
                      child: Text(
                        _controller.postPreviewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chọn nhóm lý do phù hợp nhất.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (selectedCategory == null)
                    ..._controller.categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReportFormCategoryTile(
                          title: category.title,
                          icon: category.icon,
                          onTap: () => _controller.openCategory(category),
                        ),
                      ),
                    )
                  else ...[
                    const ReportFormSectionLabel(label: 'Mục chi tiết'),
                    const SizedBox(height: 12),
                    ...selectedCategory.reasons.map(
                      (reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReportFormReasonTile(
                          title: reason.title,
                          selected: selectedReason?.key == reason.key,
                          onTap: () => _controller.selectReason(reason),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (requiresCustomReason) ...[
                      const ReportFormSectionLabel(label: 'Lý do cụ thể'),
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
                    const ReportFormSectionLabel(label: 'Chi tiết thêm'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.brightness == Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mô tả thêm (không bắt buộc)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface.withValues(
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
                                  'Bạn có thể bổ sung bối cảnh hoặc dấu hiệu cụ thể để đội ngũ kiểm duyệt xem xét chính xác hơn.',
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
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Ảnh đính kèm',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.76,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Obx(
                                () => Text(
                                  '${_controller.evidenceImages.length}/${PostReportController.maxEvidenceImages}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.54,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Obx(
                            () => Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ...List.generate(
                                  _controller.evidenceImages.length,
                                  (index) => ReportFormEvidenceImageTile(
                                    file: _controller.evidenceImages[index],
                                    onRemove:
                                        () => _controller.removeEvidenceImageAt(
                                          index,
                                        ),
                                  ),
                                ),
                                if (_controller.evidenceImages.length <
                                    PostReportController.maxEvidenceImages)
                                  ReportFormAddEvidenceTile(
                                    isLoading:
                                        _controller.isPickingImages.value,
                                    onTap: _controller.pickEvidenceImages,
                                  ),
                              ],
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
                        onPressed: Get.back,
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
