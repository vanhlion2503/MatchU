import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/verification/widgets/verification_common_widgets.dart';
import 'package:matchu_app/views/verification/widgets/verification_scanning_avatar.dart';

class FaceVerificationProcessingScreen extends StatelessWidget {
  const FaceVerificationProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 🌌 Background gradient (giữ dark để tập trung)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF020617),
              ],
            ),
          ),
        ),

        // ✨ Soft glow
        Positioned(
          top: -100,
          left: -80,
          child: FaceVerificationSoftCircle(
            size: 260,
            color: AppTheme.primaryColor.withOpacity(0.14),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -80,
          child: FaceVerificationSoftCircle(
            size: 240,
            color: AppTheme.secondaryColor.withOpacity(0.14),
          ),
        ),

        // 🎯 Content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaceVerificationScanningAvatar(
                  size: 188,
                  lineColor: AppTheme.primaryColor,
                ),

                const SizedBox(height: 22),

                // 🧠 Title
                Text(
                  'Đang xác minh...',
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onBackground,
                  ),
                ),

                const SizedBox(height: 8),

                // 📝 Subtitle
                Text(
                  'Quá trình này chỉ mất vài giây',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: colorScheme.onBackground.withOpacity(0.62),
                  ),
                ),

                const SizedBox(height: 24),

                // ⏳ Progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor:
                          colorScheme.onBackground.withOpacity(0.16),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
