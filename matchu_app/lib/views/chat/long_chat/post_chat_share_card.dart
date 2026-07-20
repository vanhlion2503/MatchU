import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_chat_share_message.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:get/get.dart';

class PostChatShareCard extends StatelessWidget {
  const PostChatShareCard({
    super.key,
    required this.message,
    required this.isMe,
  });

  final PostChatShareMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor =
        isMe
            ? theme.colorScheme.onPrimary.withValues(alpha: 0.12)
            : theme.colorScheme.surface;
    final textColor =
        isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final secondaryColor = textColor.withValues(alpha: 0.72);

    return SizedBox(
      width: 248,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.document, size: 16, color: secondaryColor),
              const SizedBox(width: 7),
              Text(
                PostTranslationKeys.sharedPost.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: secondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: textColor.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.thumbnailUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: message.thumbnailUrl,
                    width: double.infinity,
                    height: 112,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 120),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.authorName.isEmpty
                            ? PostTranslationKeys.matchuUser.tr
                            : message.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (message.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          message.excerpt,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
