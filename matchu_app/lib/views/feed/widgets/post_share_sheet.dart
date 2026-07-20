import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class PostShareSheet extends StatelessWidget {
  const PostShareSheet({
    super.key,
    required this.post,
    required this.onMatchuTap,
    required this.onShareTap,
    required this.onCopyTap,
  });

  final PostModel post;
  final Future<void> Function() onMatchuTap;
  final Future<void> Function(Rect? origin) onShareTap;
  final Future<void> Function() onCopyTap;

  static Future<void> show(
    BuildContext context, {
    required PostModel post,
    required Future<void> Function() onMatchuTap,
    required Future<void> Function(Rect? origin) onShareTap,
    required Future<void> Function() onCopyTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => PostShareSheet(
            post: post,
            onMatchuTap: onMatchuTap,
            onShareTap: onShareTap,
            onCopyTap: onCopyTap,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final target = _SharePreview.fromPost(post);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  PostTranslationKeys.shareSheetTitle.tr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: palette.iconMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PostPreviewCard(preview: target, palette: palette),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _ShareActionButton(
              icon: Iconsax.message,
              label: PostTranslationKeys.sendViaMatchu.tr,
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).colorScheme.primary,
              onTap: () => _shareInsideMatchu(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _ShareActionButton(
                  icon: Iconsax.send_1,
                  label: PostTranslationKeys.shareVia.tr,
                  foregroundColor: palette.textPrimary,
                  backgroundColor: palette.surfaceMuted,
                  onTap: () => _shareThroughAnotherApp(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareActionButton(
                  icon: Iconsax.copy,
                  label: PostTranslationKeys.copy.tr,
                  foregroundColor: palette.textPrimary,
                  backgroundColor: palette.surfaceMuted,
                  onTap: () => _copyLink(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareThroughAnotherApp(BuildContext context) {
    final renderObject = context.findRenderObject();
    final origin =
        renderObject is RenderBox && renderObject.hasSize
            ? renderObject.localToGlobal(Offset.zero) & renderObject.size
            : null;
    Navigator.of(context).pop();
    Future<void>.delayed(
      const Duration(milliseconds: 160),
      () => onShareTap(origin),
    );
  }

  void _shareInsideMatchu(BuildContext context) {
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 160), onMatchuTap);
  }

  void _copyLink(BuildContext context) {
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 160), onCopyTap);
  }
}

class _PostPreviewCard extends StatelessWidget {
  const _PostPreviewCard({required this.preview, required this.palette});

  final _SharePreview preview;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    final avatarProvider =
        preview.avatarUrl.isEmpty
            ? null
            : CachedNetworkImageProvider(preview.avatarUrl);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: palette.surface,
            backgroundImage: avatarProvider,
            child:
                avatarProvider == null
                    ? Icon(Iconsax.user, size: 19, color: palette.iconMuted)
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (preview.content.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    preview.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharePreview {
  const _SharePreview({
    required this.authorName,
    required this.avatarUrl,
    required this.content,
  });

  final String authorName;
  final String avatarUrl;
  final String content;

  factory _SharePreview.fromPost(PostModel post) {
    final reference = post.isRepostOnly ? post.referencePost : null;
    final author = reference?.author ?? post.author;
    final rawName = author.name.trim();
    return _SharePreview(
      authorName:
          rawName.isNotEmpty
              ? rawName
              : author.nickname.trim().isNotEmpty
              ? '@${author.nickname.trim()}'
              : PostTranslationKeys.matchuUser.tr,
      avatarUrl: author.avatar.trim(),
      content: (reference?.content ?? post.content).trim(),
    );
  }
}
