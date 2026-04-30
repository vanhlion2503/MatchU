import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/qr/profile_qr_controller.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQrTab extends StatefulWidget {
  const ScanQrTab({super.key, required this.controller});

  final ProfileQrController controller;

  @override
  State<ScanQrTab> createState() => _ScanQrTabState();
}

class _ScanQrTabState extends State<ScanQrTab> {
  @override
  void initState() {
    super.initState();
    widget.controller.onScannerTabReady();
  }

  @override
  void didUpdateWidget(covariant ScanQrTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.onScannerTabReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        const bottomControlsHeight = 156.0;
        final scanAreaHeight = math.max(
          160.0,
          constraints.maxHeight - bottomControlsHeight,
        );
        final scanSize = math.min(
          math.min(constraints.maxWidth * 0.72, scanAreaHeight * 0.78),
          280.0,
        );
        final scanCenter = Offset(
          constraints.maxWidth / 2,
          math.max(scanSize / 2 + 12, scanAreaHeight / 2 + 8),
        );
        final scanWindow = Rect.fromCenter(
          center: scanCenter,
          width: scanSize,
          height: scanSize,
        );

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: controller.scannerController,
                fit: BoxFit.cover,
                useAppLifecycleState: false,
                scanWindow: scanWindow,
                onDetect: controller.handleBarcodeCapture,
                placeholderBuilder:
                    (_) => ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                errorBuilder:
                    (_, error) => _ScannerErrorState(
                      message:
                          error.errorDetails?.message ??
                          'Không thể mở camera để quét mã.',
                    ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _QrScannerOverlayPainter(
                    scanWindow: scanWindow,
                    overlayColor: Colors.black.withValues(alpha: 0.42),
                    cornerColor: colorScheme.primary,
                    glowColor: colorScheme.secondary,
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 92,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đưa mã QR vào trong khung để quét',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hỗ trợ QR hồ sơ MatchU và ảnh QR trong thư viện',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: 32,
                child: Obx(() {
                  return _GlassActionButton(
                    icon: Iconsax.gallery_import,
                    label:
                        controller.isResolvingQr.value
                            ? 'Đang xử lý...'
                            : 'Tải ảnh QR từ thư viện',
                    onTap:
                        controller.isResolvingQr.value
                            ? null
                            : controller.pickQrFromGallery,
                  );
                }),
              ),
              Obx(() {
                if (!controller.isResolvingQr.value) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: Colors.black.withValues(alpha: 0.22),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(color: colorScheme.primary),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.white.withValues(alpha: onTap == null ? 0.14 : 0.22),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerErrorState extends StatelessWidget {
  const _ScannerErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.scan_barcode,
                color: Colors.white.withValues(alpha: 0.9),
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                'Không thể mở camera',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrScannerOverlayPainter extends CustomPainter {
  const _QrScannerOverlayPainter({
    required this.scanWindow,
    required this.overlayColor,
    required this.cornerColor,
    required this.glowColor,
  });

  final Rect scanWindow;
  final Color overlayColor;
  final Color cornerColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final cutoutPath =
        Path()..addRRect(
          RRect.fromRectAndRadius(scanWindow, const Radius.circular(20)),
        );
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, Paint()..color = overlayColor);

    final glowPaint =
        Paint()
          ..color = glowColor.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
    _drawCorners(canvas, scanWindow, glowPaint, 46);

    final cornerPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [cornerColor, glowColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(scanWindow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    _drawCorners(canvas, scanWindow, cornerPaint, 42);
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint, double length) {
    const radius = 2.0;
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    canvas.drawLine(
      Offset(left, top + length),
      Offset(left, top + radius),
      paint,
    );
    canvas.drawLine(
      Offset(left + radius, top),
      Offset(left + length, top),
      paint,
    );

    canvas.drawLine(
      Offset(right - length, top),
      Offset(right - radius, top),
      paint,
    );
    canvas.drawLine(
      Offset(right, top + radius),
      Offset(right, top + length),
      paint,
    );

    canvas.drawLine(
      Offset(left, bottom - length),
      Offset(left, bottom - radius),
      paint,
    );
    canvas.drawLine(
      Offset(left + radius, bottom),
      Offset(left + length, bottom),
      paint,
    );

    canvas.drawLine(
      Offset(right - length, bottom),
      Offset(right - radius, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom - length),
      Offset(right, bottom - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrScannerOverlayPainter oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        overlayColor != oldDelegate.overlayColor ||
        cornerColor != oldDelegate.cornerColor ||
        glowColor != oldDelegate.glowColor;
  }
}
