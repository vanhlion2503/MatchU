import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ShimmerColors {
  final Color base;
  final Color highlight;
  final Color surface;

  ShimmerColors({
    required this.base,
    required this.highlight,
    required this.surface,
  });

  factory ShimmerColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ShimmerColors(
      base: isDark
          ? AppTheme.shimmerDarkBase
          : AppTheme.shimmerLightBase,
      highlight: isDark
          ? AppTheme.shimmerDarkHighlight
          : AppTheme.shimmerLightHighlight,
      surface: theme.colorScheme.surface,
    );
  }
}
