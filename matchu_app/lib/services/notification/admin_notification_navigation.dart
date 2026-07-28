import 'package:get/get.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminNotificationNavigation {
  const AdminNotificationNavigation._();

  static const Map<String, String> _allowedRoutes = {
    'notifications': AppRouter.notifications,
    'settings': AppRouter.settings,
    'account_security': AppRouter.accountSecurity,
    'reputation': AppRouter.reputation,
  };

  static Future<void> open({
    required String actionType,
    required String actionValue,
  }) async {
    final normalizedType = actionType.trim();
    final normalizedValue = actionValue.trim();

    if (normalizedType == 'external_url') {
      final uri = Uri.tryParse(normalizedValue);
      if (uri != null && uri.scheme == 'https') {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final route =
        normalizedType == 'app_route'
            ? _allowedRoutes[normalizedValue]
            : AppRouter.notifications;
    final resolvedRoute = route ?? AppRouter.notifications;
    if (Get.currentRoute != resolvedRoute) {
      await Get.toNamed(resolvedRoute);
    }
  }
}
