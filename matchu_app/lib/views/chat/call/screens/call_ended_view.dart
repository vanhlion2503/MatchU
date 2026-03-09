import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class CallEndedView extends StatelessWidget {
  const CallEndedView({
    super.key,
    required this.summary,
    required this.statusText,
    required this.durationText,
    required this.onRedial,
    required this.onMessage,
  });

  final CallEndedSummary summary;
  final String statusText;
  final String durationText;
  final Future<void> Function() onRedial;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor =
        isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final textPrimary = isDark ? Colors.white : Colors.black87;

    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? Colors.black.withOpacity(0.6)
                              : Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _buildAvatar(
                    avatarUrl: summary.peerAvatarUrl,
                    backgroundColor: backgroundColor,
                    iconColor: textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// Name
              VerifiedNameRow(
                isVerified: summary.isPeerVerified,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                useFlexibleChild: false,
                child: Text(
                  summary.peerName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              /// Status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Iconsax.call_received,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              /// Duration
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  durationText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              /// Redial
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async => await onRedial(),
                  icon: const Icon(Iconsax.call),
                  label: const Text("Gọi lại"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// Message
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Iconsax.previous),
                  label: const Text("Thoát"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({
    required String avatarUrl,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    if (avatarUrl.isEmpty) {
      return ColoredBox(
        color: backgroundColor,
        child: Center(child: Icon(Icons.person, size: 42, color: iconColor)),
      );
    }

    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => ColoredBox(
            color: backgroundColor,
            child: Center(
              child: Icon(Icons.person, size: 42, color: iconColor),
            ),
          ),
    );
  }
}
