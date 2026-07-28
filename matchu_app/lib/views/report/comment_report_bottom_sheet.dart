import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/report/comment_report_controller.dart';
import 'package:matchu_app/models/feed/post_comment_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/report/report_form_widgets.dart';

class CommentReportBottomSheet extends StatefulWidget {
  const CommentReportBottomSheet({
    super.key,
    required this.postId,
    required this.comment,
  });

  final String postId;
  final PostCommentModel comment;

  static Future<bool?> show({
    required String postId,
    required PostCommentModel comment,
  }) {
    return Get.bottomSheet<bool>(
      CommentReportBottomSheet(postId: postId, comment: comment),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<CommentReportBottomSheet> createState() =>
      _CommentReportBottomSheetState();
}

class _CommentReportBottomSheetState extends State<CommentReportBottomSheet> {
  late final String _tag;
  late final CommentReportController _controller;

  @override
  void initState() {
    super.initState();
    _tag =
        'comment-report-${widget.comment.commentId}-${identityHashCode(this)}';
    _controller = Get.put(
      CommentReportController(postId: widget.postId, comment: widget.comment),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<CommentReportController>(tag: _tag)) {
      Get.delete<CommentReportController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
          final category = _controller.selectedCategory.value;
          final reason = _controller.selectedReason.value;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outline.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (category != null)
                      IconButton(
                        onPressed: _controller.goBackToCategories,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        category?.title ?? 'Báo cáo bình luận'.tr,
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
                if (category == null) ...[
                  Text(
                    'Bình luận của ${_controller.authorName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            theme.brightness == Brightness.dark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder,
                      ),
                    ),
                    child: Text(
                      _controller.preview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._controller.categories.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReportFormCategoryTile(
                        title: item.title,
                        icon: item.icon,
                        onTap: () => _controller.openCategory(item),
                      ),
                    ),
                  ),
                ] else ...[
                  const ReportFormSectionLabel(label: 'Mục chi tiết'),
                  const SizedBox(height: 12),
                  ...category.reasons.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ReportFormReasonTile(
                        title: item.title,
                        selected: reason?.key == item.key,
                        onTap: () => _controller.selectReason(item),
                      ),
                    ),
                  ),
                  if (_controller.requiresCustomReason) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller.customReasonController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        hintText: 'Nhập lý do cụ thể',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller.descriptionController,
                    maxLines: 4,
                    maxLength: 400,
                    decoration: const InputDecoration(
                      labelText: 'Chi tiết thêm (không bắt buộc)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
