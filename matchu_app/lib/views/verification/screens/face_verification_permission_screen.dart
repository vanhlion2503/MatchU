import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
class FaceVerificationPermissionScreen extends StatelessWidget {
  const FaceVerificationPermissionScreen({
    super.key,
    required this.message,
    required this.onOpenSettings,
    required this.onClose,
  });

  final String message;
  final VoidCallback onOpenSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1220),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 62,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onOpenSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mở cài đặt'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onClose, child: const Text('Đóng')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
