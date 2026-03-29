import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_video_thumbnail.dart';

class PostMediaGallery extends StatelessWidget {
  const PostMediaGallery({super.key, required this.media});

  final List<MediaModel> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final palette = FeedPalette.of(context);
    const borderRadius = BorderRadius.all(Radius.circular(18));

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: borderRadius,
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (media.length == 1) {
              final item = media.first;
              final height =
                  item.isVideo
                      ? math.min(constraints.maxWidth * 0.72, 320.0)
                      : math.min(constraints.maxWidth * 1.02, 380.0);

              return SizedBox(
                height: height,
                width: double.infinity,
                child: _MediaTile(
                  media: item,
                  borderRadius: BorderRadius.zero,
                  useIntrinsicVideoAspectRatio: false,
                ),
              );
            }

            final crossAxisCount = constraints.maxWidth >= 620 ? 3 : 2;
            const spacing = 2.0;
            final width =
                constraints.maxWidth - ((crossAxisCount - 1) * spacing);
            final itemExtent = width / crossAxisCount;

            return GridView.builder(
              shrinkWrap: true,
              itemCount: media.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: itemExtent,
              ),
              itemBuilder: (_, index) {
                return _MediaTile(
                  media: media[index],
                  borderRadius: BorderRadius.zero,
                  useIntrinsicVideoAspectRatio: false,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.borderRadius,
    required this.useIntrinsicVideoAspectRatio,
  });

  final MediaModel media;
  final BorderRadius borderRadius;
  final bool useIntrinsicVideoAspectRatio;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);

    if (media.isVideo) {
      return PostVideoThumbnail(
        url: media.url,
        borderRadius: borderRadius,
        useIntrinsicAspectRatio: useIntrinsicVideoAspectRatio,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: media.url,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => ColoredBox(
              color: palette.surfaceMuted,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget:
            (_, __, ___) => ColoredBox(
              color: palette.surfaceMuted,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 30),
              ),
            ),
      ),
    );
  }
}
