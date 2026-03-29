import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

class FeedPalette {
  const FeedPalette({
    required this.pageBackground,
    required this.headerBackground,
    required this.surface,
    required this.surfaceMuted,
    required this.inputSurface,
    required this.border,
    required this.threadLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconPrimary,
    required this.iconMuted,
    required this.likeColor,
    required this.shadowColor,
  });

  final Color pageBackground;
  final Color headerBackground;
  final Color surface;
  final Color surfaceMuted;
  final Color inputSurface;
  final Color border;
  final Color threadLine;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color iconPrimary;
  final Color iconMuted;
  final Color likeColor;
  final Color shadowColor;

  factory FeedPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FeedPalette(
      pageBackground:
          isDark ? const Color(0xFF090D14) : const Color(0xFFFAFAFA),
      headerBackground:
          isDark ? const Color(0xE6141821) : const Color(0xF2FFFFFF),
      surface: isDark ? const Color(0xFF11151F) : Colors.white,
      surfaceMuted: isDark ? const Color(0xFF171C27) : const Color(0xFFF5F5F5),
      inputSurface: isDark ? const Color(0xFF171C27) : const Color(0xFFF6F6F7),
      border: isDark ? const Color(0xFF242B38) : const Color(0xFFE8EBEF),
      threadLine: isDark ? const Color(0xFF313847) : const Color(0xFFD8DDE5),
      textPrimary: theme.colorScheme.onSurface,
      textSecondary:
          isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
      textTertiary: isDark ? const Color(0xFF8F97A4) : const Color(0xFF7A828E),
      iconPrimary: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF171717),
      iconMuted: isDark ? const Color(0xFFB7BECA) : const Color(0xFF5F6670),
      likeColor: const Color(0xFFE11D48),
      shadowColor:
          isDark
              ? Colors.black.withValues(alpha: 0.26)
              : const Color(0x120F172A),
    );
  }
}
