import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

Widget lightningIcon(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                AppTheme.darkSurface,
                AppTheme.darkBackground,
              ]
            : [
                AppTheme.lightSurface,
                AppTheme.lightBackground,
              ],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.flash_on, // ⚡ icon tia sét
        size: 20,
        color: theme.colorScheme.onPrimary,
      ),
    ),
  );
}
