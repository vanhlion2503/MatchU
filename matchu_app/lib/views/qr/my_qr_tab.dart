import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/qr/profile_qr_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQrTab extends StatelessWidget {
  const MyQrTab({super.key, required this.controller});

  final ProfileQrController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.currentUserRx.value;
      final isSharing = controller.isSharingQr.value;
      if (user == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            RepaintBoundary(
              key: controller.qrBoundaryKey,
              child: _MyQrCard(controller: controller, user: user),
            ),
            const SizedBox(height: 18),
            _PrimaryQrActionButton(
              icon: Iconsax.share,
              label: isSharing ? 'Đang chia sẻ...' : 'Chia sẻ mã',
              isLoading: isSharing,
              onTap: (buttonContext) {
                controller.shareQrImage(
                  sharePositionOrigin: _sharePositionOrigin(buttonContext),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
        ),
      );
    });
  }
}

class _MyQrCard extends StatelessWidget {
  const _MyQrCard({required this.controller, required this.user});

  final ProfileQrController controller;
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final qrData = ProfileQrController.buildProfileQrPayload(user.uid);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: (theme.brightness == Brightness.dark
        ? AppTheme.darkBorder
        : AppTheme.lightBorder).withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _QrProfileAvatar(user: user),
          const SizedBox(height: 14),
          Text(
            user.fullname.isNotEmpty ? user.fullname : user.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.nickname}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          _QrCodeFrame(data: qrData),
          const SizedBox(height: 18),
          Text(
            'Quét mã này để thêm tôi làm bạn',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrProfileAvatar extends StatelessWidget {
  const _QrProfileAvatar({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkBorder
            : AppTheme.lightBorder;

    return CircleAvatar(
      radius: 35,
      backgroundColor: backgroundColor,
      backgroundImage:
          user.avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(user.avatarUrl)
              : null,
      child:
          user.avatarUrl.isEmpty
              ? Text(
                _initialOf(user),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              )
              : null,
    );
  }

  String _initialOf(UserModel user) {
    final source = user.nickname.isNotEmpty ? user.nickname : user.fullname;
    if (source.isEmpty) return '?';
    return source.characters.first.toUpperCase();
  }
}

class _QrCodeFrame extends StatelessWidget {
  const _QrCodeFrame({required this.data});

  final String data;
  static const String _appIconAsset = 'assets/icon/IconApp.png';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const outerSize = 226.0;
    const qrSize = 200.0;
    const centerLogoSize = 45.0;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(outerSize),
            painter: _QrCornerFramePainter(
              primaryColor: colorScheme.primary,
              secondaryColor: colorScheme.secondary,
            ),
          ),
          Container(
            width: qrSize,
            height: qrSize,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  color: Colors.white,
                  child: QrImageView(
                    data: data,
                    padding: const EdgeInsets.all(10),
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  width: centerLogoSize,
                  height: centerLogoSize,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(_appIconAsset, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryQrActionButton extends StatelessWidget {
  const _PrimaryQrActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isLoading;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : () => onTap(context),
            borderRadius: BorderRadius.circular(26),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, size: 20, color: Colors.white),
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
      ),
    );
  }
}

Rect? _sharePositionOrigin(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;

  final topLeft = renderObject.localToGlobal(Offset.zero);
  return topLeft & renderObject.size;
}

class _QrCornerFramePainter extends CustomPainter {
  const _QrCornerFramePainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..shader = LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;

    const length = 42.0;
    const inset = 2.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    canvas.drawLine(Offset(left, top), Offset(left + length, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + length), paint);

    canvas.drawLine(Offset(right, top), Offset(right - length, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + length), paint);

    canvas.drawLine(Offset(left, bottom), Offset(left + length, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - length), paint);

    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - length, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrCornerFramePainter oldDelegate) {
    return primaryColor != oldDelegate.primaryColor ||
        secondaryColor != oldDelegate.secondaryColor;
  }
}
