import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false, 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 60,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: theme.brightness == Brightness.dark 
                  ? AppTheme.darkBorder 
                  : AppTheme.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ---------------- LEFT SIDE ----------------
            Row(
              children: [
                // App logo (demo) + name
                Image.asset(
                  'assets/icon/Icon.png',
                  width: 40,
                  fit: BoxFit.contain,
                ),
      
                const SizedBox(width: 8),
      
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkTextPrimary 
                        : AppTheme.lightTextPrimary,
                  ),
                ),
              ],
            ),
      
            // ---------------- RIGHT SIDE ----------------
            Row(
              children: [
                // Search icon
                Icon(Icons.search, size: 24, color: theme.iconTheme.color),
      
                const SizedBox(width: 18),
      
                // Notification icon with small red dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none, size: 24, color: theme.iconTheme.color),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
      
                const SizedBox(width: 18),
      
                // Avatar circle
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
