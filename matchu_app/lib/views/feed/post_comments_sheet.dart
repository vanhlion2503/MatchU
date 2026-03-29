import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/comment_tree_item.dart';

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({
    super.key,
    required this.post,
    this.onCommentCountChanged,
  });

  final PostModel post;
  final ValueChanged<int>? onCommentCountChanged;

  static Future<void> show(
    BuildContext context, {
    required PostModel post,
    ValueChanged<int>? onCommentCountChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PostCommentsSheet(
            post: post,
            onCommentCountChanged: onCommentCountChanged,
          ),
    );
  }

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  late final String _tag;
  late final PostCommentsController _controller;

  @override
  void initState() {
    super.initState();
    _tag = 'post_comments_${widget.post.postId}';
    _controller = Get.put(
      PostCommentsController(
        postId: widget.post.postId,
        onCommentCountChanged: widget.onCommentCountChanged,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<PostCommentsController>(tag: _tag)) {
      Get.delete<PostCommentsController>(tag: _tag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => Text(
                          'Binh luan (${_controller.comments.length})',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: Navigator.of(context).pop,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(() {
                  if (_controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_controller.errorMessage.value != null &&
                      _controller.comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 44),
                            const SizedBox(height: 12),
                            Text(
                              _controller.errorMessage.value!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _controller.loadComments,
                              child: const Text('Thu lai'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (_controller.threadEntries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Chua co binh luan nao. Hay mo dau cuoc tro chuyen.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: _controller.threadEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = _controller.threadEntries[index];
                      return CommentTreeItem(
                        entry: entry,
                        onReplyTap: () => _controller.startReply(entry.comment),
                      );
                    },
                  );
                }),
              ),
              const Divider(height: 1),
              Obx(() {
                final replyingTo = _controller.replyingTo.value;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyingTo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        color: theme.colorScheme.surface.withValues(alpha: 0.8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Dang tra loi ${replyingTo.author?.displayName ?? 'nguoi dung'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _controller.cancelReply,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller.inputController,
                              focusNode: _controller.inputFocusNode,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Nhap binh luan...',
                              ),
                              onSubmitted: (_) => _controller.submitComment(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Obx(
                            () => FilledButton(
                              onPressed:
                                  _controller.isSubmitting.value
                                      ? null
                                      : _controller.submitComment,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                              ),
                              child:
                                  _controller.isSubmitting.value
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(Icons.send_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
