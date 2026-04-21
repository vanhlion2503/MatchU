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
    required this.repostColor,
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
  final Color repostColor;
  final Color shadowColor;

  factory FeedPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FeedPalette(
      pageBackground:
          isDark ? AppTheme.darkBackground : const Color(0xFFFAFAFA),
      headerBackground:
          isDark
              ? AppTheme.darkBackground.withValues(alpha: 0.95)
              : const Color(0xF2FFFFFF),
      surface: isDark ? AppTheme.darkBackground : Colors.white,
      surfaceMuted: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F5),
      inputSurface: isDark ? AppTheme.darkSurface : const Color(0xFFF6F6F7),
      border: isDark ? AppTheme.darkBorder : const Color(0xFFE8EBEF),
      threadLine:
          isDark
              ? AppTheme.darkBorder.withValues(alpha: 0.92)
              : const Color(0xFFD8DDE5),
      textPrimary: theme.colorScheme.onSurface,
      textSecondary:
          isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
      textTertiary: isDark ? const Color(0xFF8F97A4) : const Color(0xFF7A828E),
      iconPrimary: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF171717),
      iconMuted: isDark ? const Color(0xFFB7BECA) : const Color(0xFF5F6670),
      likeColor: const Color(0xFFE11D48),
      repostColor: const Color(0xFF059669),
      shadowColor:
          isDark
              ? Colors.black.withValues(alpha: 0.26)
              : const Color(0x120F172A),
    );
  }
}
