import 'package:flutter/material.dart';
import 'package:matchu_app/views/verification/widgets/verification_common_widgets.dart';

class FaceVerificationFailedScreen extends StatelessWidget {
  const FaceVerificationFailedScreen({
    super.key,
    required this.errorText,
    required this.hasCameraPermission,
    required this.onBack,
    required this.onRetry,
    required this.onRetryLater,
    required this.onOpenPermissionSettings,
  });

  final String errorText;
  final bool hasCameraPermission;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final VoidCallback onRetryLater;
  final VoidCallback onOpenPermissionSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              FaceVerificationGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFDEBD8),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFF97316),
              size: 52,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa xác thực được',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorText.isEmpty
                ? 'Hệ thống chưa thể xác nhận khuôn mặt của bạn khớp với hồ sơ.'
                : errorText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Lý do thường gặp',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _ReasonTile(
            icon: Icons.blur_on_outlined,
            label: 'Khuôn mặt bị mờ hoặc quá tối',
          ),
          const SizedBox(height: 8),
          const _ReasonTile(
            icon: Icons.visibility_off_outlined,
            label: 'Đang đeo kính râm hoặc khẩu trang',
          ),
          const SizedBox(height: 8),
          const _ReasonTile(
            icon: Icons.screen_rotation_alt_outlined,
            label: 'Chuyển động chưa đúng hướng dẫn',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Thử lại ngay'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetryLater,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Xác thực sau'),
            ),
          ),
          if (!hasCameraPermission)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: onOpenPermissionSettings,
                child: const Text('Mở cài đặt quyền camera'),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surface,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: colorScheme.onSurface.withOpacity(0.45),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

