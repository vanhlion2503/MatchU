import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';

class BackCircleButton extends StatefulWidget {
  /// Hành động khi nhấn
  /// - Nếu không truyền -> mặc định Get.back()
  final VoidCallback? onTap;

  /// Dịch chuyển vị trí (ví dụ đẩy lên trên)
  final Offset offset;

  /// Kích thước nút (đường kính)
  final double size;

  /// Kích thước icon
  final double iconSize;

  const BackCircleButton({
    super.key,
    this.onTap,
    this.offset = const Offset(0, 0),
    this.size = 40,
    this.iconSize = 18,
  });

  @override
  State<BackCircleButton> createState() => _BackCircleButtonState();
}

class _BackCircleButtonState extends State<BackCircleButton> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Transform.translate(
      offset: widget.offset,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              // 🎨 NỀN: ăn theo AppTheme
              color: theme.scaffoldBackgroundColor,

              // 🎨 VIỀN: lightBorder / darkBorder
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder ,
                width: 1,
              ),

              // 🌫 SHADOW: tinh tế, khác light / dark
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    isDark ? 0.35 : 0.06,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_ios_new,
              size: widget.iconSize,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
      ),
    );
  }
}
