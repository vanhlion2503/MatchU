import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/system/network_controller.dart';

/// A non-dismissible, app-wide offline dialog above every route and sheet.
class NetworkOfflineOverlay extends StatefulWidget {
  const NetworkOfflineOverlay({super.key});

  @override
  State<NetworkOfflineOverlay> createState() => _NetworkOfflineOverlayState();
}

class _NetworkOfflineOverlayState extends State<NetworkOfflineOverlay>
    with SingleTickerProviderStateMixin {
  final NetworkController _controller = Get.find<NetworkController>();
  late final AnimationController _iconAnimation;

  @override
  void initState() {
    super.initState();
    _iconAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!_controller.isReady.value ||
          (!_controller.shouldShowOfflineOverlay.value &&
              !_controller.isRetrying.value)) {
        return const SizedBox.shrink();
      }

      final isVietnamese = Get.locale?.languageCode != 'en';
      return Positioned.fill(
        child: Material(
          color: Colors.black.withValues(alpha: 0.58),
          child: PopScope(
            canPop: false,
            child: Center(
              child:
                  _controller.isRetrying.value
                      ? _ReconnectLoadingCard(isVietnamese: isVietnamese)
                      : _OfflineCard(
                        isVietnamese: isVietnamese,
                        retryFailed: _controller.lastRetryFailed.value,
                        iconAnimation: _iconAnimation,
                        onRetry: _controller.retryConnection,
                      ),
            ),
          ),
        ),
      );
    });
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
    );
  }
}

class _ReconnectLoadingCard extends StatelessWidget {
  const _ReconnectLoadingCard({required this.isVietnamese});

  final bool isVietnamese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              width: 220,
              height: 8,
              child: LinearProgressIndicator(
                color: colors.primary,
                backgroundColor: colors.primary.withValues(alpha: 0.16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isVietnamese ? 'Đang kết nối lại...' : 'Reconnecting...',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isVietnamese
                ? 'Vui lòng chờ trong giây lát.'
                : 'Please wait a moment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({
    required this.isVietnamese,
    required this.retryFailed,
    required this.iconAnimation,
    required this.onRetry,
  });

  final bool isVietnamese;
  final bool retryFailed;
  final Animation<double> iconAnimation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description =
        retryFailed
            ? (isVietnamese
                ? 'Kết nối lại không thành công. Hãy kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại.'
                : 'Reconnect failed. Check your Wi-Fi or mobile data, then try again.')
            : (isVietnamese
                ? 'Hãy kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại.'
                : 'Check your Wi-Fi or mobile data, then try again.');

    return _DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: iconAnimation,
            child: Container(
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
            builder:
                (context, child) => Transform.rotate(
                  angle: -0.045 + (iconAnimation.value * 0.09),
                  child: child,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            isVietnamese ? 'Không có kết nối mạng' : 'No internet connection',
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
              color:
                  retryFailed
                      ? colors.error
                      : colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              child: Text(isVietnamese ? 'Thử lại' : 'Try again'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: SystemNavigator.pop,
            child: Text(isVietnamese ? 'Thoát app' : 'Exit app'),
          ),
        ],
      ),
    );
  }
}
