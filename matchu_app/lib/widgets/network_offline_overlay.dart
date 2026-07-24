import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/system/network_controller.dart';

/// A non-dismissible, app-wide offline dialog. It is placed in
/// GetMaterialApp.builder so it remains above every route and bottom sheet.
class NetworkOfflineOverlay extends GetView<NetworkController> {
  const NetworkOfflineOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isReady.value || !controller.isOffline.value) {
        return const SizedBox.shrink();
      }

      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final isVietnamese = Get.locale?.languageCode != 'en';
      final title =
          isVietnamese ? 'Không có kết nối mạng' : 'No internet connection';
      final description =
          isVietnamese
              ? 'Hãy kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại.'
              : 'Check your Wi-Fi or mobile data, then try again.';
      final retryLabel = isVietnamese ? 'Thử lại' : 'Try again';
      final exitLabel = isVietnamese ? 'Thoát app' : 'Exit app';

      return Positioned.fill(
        child: Material(
          color: Colors.black.withValues(alpha: 0.58),
          child: PopScope(
            canPop: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          color: colors.error,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              controller.isChecking.value
                                  ? null
                                  : controller.checkConnection,
                          child:
                              controller.isChecking.value
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(retryLabel),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: SystemNavigator.pop,
                        child: Text(exitLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
