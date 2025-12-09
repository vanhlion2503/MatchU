import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

Widget genderButton(
  BuildContext context, {
  required String label,
  required String value,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium!.copyWith(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w600,
                ),
          ),
        ),
      ),
    ),
  );
}
