import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_composer_controller.dart';
import 'package:matchu_app/models/feed/post_media_draft.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/theme/app_theme.dart';

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  static Future<PostModel?> show(BuildContext context) {
    return showModalBottomSheet<PostModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(),
    );
  }

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  late final String _tag;
  late final PostComposerController _controller;

  @override
  void initState() {
    super.initState();
    _tag = 'post_composer_${DateTime.now().microsecondsSinceEpoch}';
    _controller = Get.put(PostComposerController(), tag: _tag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<PostComposerController>(tag: _tag)) {
      Get.delete<PostComposerController>(tag: _tag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
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
                    child: Text(
                      'Tao bai viet',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => TextField(
                        controller: _controller.contentController,
                        maxLines: 6,
                        minLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Ban dang nghi gi? Noi dung toi da 300 ky tu.',
                          alignLabelWithHint: true,
                          suffixText:
                              '${_controller.remainingCharacters}/${PostService.maxContentLength}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller.tagsController,
                      decoration: const InputDecoration(
                        hintText:
                            'Tags (phan tach boi dau phay hoac khoang trang)',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _controller.pickImages,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Them anh'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _controller.pickVideo,
                            icon: const Icon(Icons.videocam_outlined),
                            label: const Text('Them video'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Obx(() {
                      if (_controller.mediaDrafts.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.75,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          child: Text(
                            'Chua co media nao duoc chon.',
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _controller.mediaDrafts
                            .map(
                              (draft) => _DraftMediaCard(
                                draft: draft,
                                onRemove: () => _controller.removeMedia(draft),
                              ),
                            )
                            .toList(growable: false),
                      );
                    }),
                    const SizedBox(height: 18),
                    Obx(
                      () => SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Dang cong khai'),
                        subtitle: const Text(
                          'Neu tat, bai viet van duoc tao nhung se khong hien trong feed cong khai.',
                        ),
                        value: _controller.isPublic.value,
                        onChanged:
                            _controller.isSubmitting.value
                                ? null
                                : (value) => _controller.isPublic.value = value,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              _controller.canSubmit
                                  ? () async {
                                    final created = await _controller.submit();
                                    if (created == null) return;
                                    Get.back<PostModel?>(result: created);
                                  }
                                  : null,
                          icon:
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
                          label: Text(
                            _controller.isSubmitting.value
                                ? 'Dang dang bai...'
                                : 'Dang bai viet',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftMediaCard extends StatelessWidget {
  const _DraftMediaCard({required this.draft, required this.onRemove});

  final PostMediaDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  theme.brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.lightBorder,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child:
                draft.isImage
                    ? Image.file(draft.file, fit: BoxFit.cover)
                    : Container(
                      color: const Color(0xFF111827),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          const Spacer(),
                          Text(
                            draft.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
