import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/verification/widgets/verification_common_widgets.dart';
import 'package:matchu_app/views/verification/widgets/verification_scanning_avatar.dart';

class FaceVerificationProcessingScreen extends StatelessWidget {
  const FaceVerificationProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
            ),
          ),
        ),
        Positioned(
          top: -100,
          left: -80,
          child: FaceVerificationSoftCircle(
            size: 260,
            color: AppTheme.primaryColor.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -80,
          child: FaceVerificationSoftCircle(
            size: 240,
            color: AppTheme.secondaryColor.withValues(alpha: 0.14),
          ),
        ),
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
                const Text(
                  'Đang xác minh...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quá trình này chỉ mất vài giây',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
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
        const Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: FaceVerificationPhoneHomeIndicator(dark: true),
        ),
      ],
    );
  }
}
