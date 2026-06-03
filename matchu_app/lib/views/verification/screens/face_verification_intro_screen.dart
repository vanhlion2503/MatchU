import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/verification/widgets/verification_common_widgets.dart';

class FaceVerificationIntroScreen extends StatelessWidget {
  const FaceVerificationIntroScreen({
    super.key,
    this.title,
    this.description,
    this.primaryButtonLabel,
    required this.onBack,
    required this.onStart,
  });

  final String? title;
  final String? description;
  final String? primaryButtonLabel;
  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: FaceVerificationSoftCircle(
            size: 260,
            color: colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        Positioned(
          bottom: 90,
          left: -60,
          child: FaceVerificationSoftCircle(
            size: 220,
            color: AppTheme.secondaryColor.withValues(alpha: 0.16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              const SizedBox(height: 38),
              Row(
                children: [
                  FaceVerificationGlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.18),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.face_retouching_natural,
                        size: 62,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                title ?? 'Xác thực khuôn mặt',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description ??
                    'Giúp cộng đồng an toàn và đáng tin cậy hơn. Quá trình này hoàn toàn riêng tư.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 26),
              const _IntroStepTile(
                icon: Icons.camera_alt_outlined,
                label: 'Chụp ảnh selfie chân dung',
              ),
              const SizedBox(height: 12),
              const _IntroStepTile(
                icon: Icons.face_6_outlined,
                label: 'Xác thực chuyển động khuôn mặt',
              ),
              const SizedBox(height: 12),
              const _IntroStepTile(
                icon: Icons.timer_outlined,
                label: 'Hoàn tất trong khoảng 30 giây',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(primaryButtonLabel ?? 'Bắt đầu xác thực'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chỉ dùng cho xác minh, không hiển thị công khai',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroStepTile extends StatelessWidget {
  const _IntroStepTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface, // 👈 lightSurface / darkSurface
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : Colors.white,
              shape: BoxShape.circle,
              boxShadow:
                  isDark
                      ? null
                      : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
