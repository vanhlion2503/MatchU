import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class FeedAvatar extends StatelessWidget {
  const FeedAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackLabel,
    required this.size,
    this.borderWidth = 1,
    this.borderColor,
    this.backgroundColor,
    this.textStyle,
  });

  final String imageUrl;
  final String fallbackLabel;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final trimmedUrl = imageUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? palette.border,
          width: borderWidth,
        ),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor ?? palette.surfaceMuted,
        backgroundImage:
            trimmedUrl.isNotEmpty
                ? CachedNetworkImageProvider(trimmedUrl)
                : null,
        child:
            trimmedUrl.isEmpty
                ? Text(
                  initialOf(fallbackLabel),
                  style:
                      textStyle ??
                      theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                )
                : null,
      ),
    );
  }
}

String postAuthorName(PostModel post) {
  final trimmedName = post.author.name.trim();
  if (trimmedName.isNotEmpty) return trimmedName;

  final handle = postAuthorHandle(post);
  if (handle.isNotEmpty) return handle;

  return 'Người dùng';
}

String postAuthorHandle(PostModel post) {
  final nickname = post.author.nickname.trim();
  if (nickname.isNotEmpty) return nickname;

  final displayName = post.author.name.trim();
  if (displayName.isNotEmpty) return displayName;

  return '';
}

String formatRelativeTime(
  DateTime? dateTime, {
  bool withSuffix = false,
  bool compact = false,
}) {
  if (dateTime == null) {
    return _justNowLabel();
  }

  final localTime = dateTime.toLocal();
  final diff = DateTime.now().difference(localTime);
  if (diff.isNegative || diff.inSeconds < 60) {
    return _justNowLabel();
  }

  if (diff.inMinutes < 60) {
    return _formatRelativeUnit(
      value: diff.inMinutes,
      fullUnit: 'ph\u00FAt',
      compactUnit: 'p',
      withSuffix: withSuffix,
      compact: compact,
    );
  }

  if (diff.inHours < 24) {
    return _formatRelativeUnit(
      value: diff.inHours,
      fullUnit: 'gi\u1EDD',
      compactUnit: 'g',
      withSuffix: withSuffix,
      compact: compact,
    );
  }

  if (diff.inDays < 7) {
    return _formatRelativeUnit(
      value: diff.inDays,
      fullUnit: 'ng\u00E0y',
      compactUnit: 'ng',
      withSuffix: withSuffix,
      compact: compact,
    );
  }

  final hasSameYear = localTime.year == DateTime.now().year;
  return DateFormat(hasSameYear ? 'dd/MM' : 'dd/MM/yyyy').format(localTime);
}

String formatAbsolutePostTime(DateTime? dateTime) {
  if (dateTime == null) return _justNowLabel();
  return DateFormat('HH:mm, dd/MM/yyyy').format(dateTime.toLocal());
}

String formatPostMetaDate(DateTime? dateTime) {
  if (dateTime == null) return _justNowLabel();
  return DateFormat('dd/MM').format(dateTime.toLocal());
}

String buildPostMetaLabel(PostModel post) {
  final authorName = postAuthorName(post);
  final handle = postAuthorHandle(post);
  final hasDistinctHandle =
      handle.isNotEmpty && handle.toLowerCase() != authorName.toLowerCase();

  if (!hasDistinctHandle) return '';
  return '@$handle';
}

String formatCompactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final compact = value / 1000;
    return compact % 1 == 0
        ? '${compact.toStringAsFixed(0)}K'
        : '${compact.toStringAsFixed(1)}K';
  }

  final compact = value / 1000000;
  return compact % 1 == 0
      ? '${compact.toStringAsFixed(0)}M'
      : '${compact.toStringAsFixed(1)}M';
}

String initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

String _formatRelativeUnit({
  required int value,
  required String fullUnit,
  required String compactUnit,
  required bool withSuffix,
  required bool compact,
}) {
  if (compact) return '$value$compactUnit';

  final label = '$value $fullUnit';
  if (!withSuffix) return label;
  return '$label tr\u01B0\u1EDBc';
}

String _justNowLabel() {
  return 'V\u1EEBa xong';
}
