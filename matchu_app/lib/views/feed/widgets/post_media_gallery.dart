import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_image_viewer_screen.dart';
import 'package:matchu_app/views/feed/widgets/post_video_thumbnail.dart';

enum PostMediaGalleryMultiImageLayout { grid, horizontalScroll }

class PostMediaGallery extends StatelessWidget {
  const PostMediaGallery({
    super.key,
    required this.media,
    this.multiImageLayout = PostMediaGalleryMultiImageLayout.grid,
  });

  final List<MediaModel> media;
  final PostMediaGalleryMultiImageLayout multiImageLayout;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final palette = FeedPalette.of(context);
    const borderRadius = BorderRadius.all(Radius.circular(18));
    final hasOnlyImages = media.every((item) => item.isImage);
    final imageUrls = media
        .where((item) => item.isImage)
        .map((item) => item.url)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    final useHorizontalImageScroll =
        hasOnlyImages &&
        media.length >= 2 &&
        multiImageLayout == PostMediaGalleryMultiImageLayout.horizontalScroll;

    if (useHorizontalImageScroll) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
          final cardWidth =
              maxWidth >= 620
                  ? 228.0
                  : (maxWidth * 0.62).clamp(148.0, 186.0).toDouble();
          final cardHeight = cardWidth * 1.25;

          return SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                return SizedBox(
                  width: cardWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: borderRadius,
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: _MediaTile(
                        media: media[index],
                        borderRadius: BorderRadius.zero,
                        useIntrinsicVideoAspectRatio: false,
                        onTap:
                            media[index].url.isEmpty || imageUrls.isEmpty
                                ? null
                                : () => _openImageViewer(
                                  context,
                                  imageUrls: imageUrls,
                                  initialIndex: _imageIndexForMediaPosition(
                                    index,
                                  ),
                                ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

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
                  onTap:
                      item.isImage &&
                              item.url.isNotEmpty &&
                              imageUrls.isNotEmpty
                          ? () => _openImageViewer(
                            context,
                            imageUrls: imageUrls,
                            initialIndex: 0,
                          )
                          : null,
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
                  onTap:
                      media[index].isImage && media[index].url.isNotEmpty
                          ? () => _openImageViewer(
                            context,
                            imageUrls: imageUrls,
                            initialIndex: _imageIndexForMediaPosition(index),
                          )
                          : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  int _imageIndexForMediaPosition(int mediaIndex) {
    var imageIndex = -1;
    for (var i = 0; i <= mediaIndex && i < media.length; i++) {
      if (media[i].isImage && media[i].url.isNotEmpty) {
        imageIndex++;
      }
    }
    return imageIndex < 0 ? 0 : imageIndex;
  }

  Future<void> _openImageViewer(
    BuildContext context, {
    required List<String> imageUrls,
    required int initialIndex,
  }) {
    if (imageUrls.isEmpty) {
      return Future<void>.value();
    }

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => PostImageViewerScreen(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
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
    this.onTap,
  });

  final MediaModel media;
  final BorderRadius borderRadius;
  final bool useIntrinsicVideoAspectRatio;
  final VoidCallback? onTap;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                    child: Icon(Iconsax.gallery_slash, size: 30),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
