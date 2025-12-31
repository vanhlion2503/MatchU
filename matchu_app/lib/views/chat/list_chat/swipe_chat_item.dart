import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class SwipeChatItemMessage extends StatefulWidget {
  final Widget child;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  const SwipeChatItemMessage({
    super.key,
    required this.child,
    required this.onPin,
    required this.onDelete,
    required this.onMore,
  });

  @override
  State<SwipeChatItemMessage> createState() => _SwipeChatItemMessageState();
}

class _SwipeChatItemMessageState extends State<SwipeChatItemMessage>
    with SingleTickerProviderStateMixin {
  static const double tileWidth = 72;
  static const int tileCount = 3;
  static const double maxOffset = tileWidth * tileCount;
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Curve _animationCurve = Curves.easeOutCubic;

  late AnimationController _animationController;
  late Animation<double> _offsetAnimation;
  double _dragOffset = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _offsetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: _animationCurve,
      ),
    );
    _offsetAnimation.addListener(() {
      if (_isAnimating) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _currentOffset {
    if (_isAnimating) {
      return _offsetAnimation.value;
    }
    return _dragOffset;
  }

  void _animateTo(double target) {
    _isAnimating = true;
    _offsetAnimation = Tween<double>(
      begin: _dragOffset,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: _animationCurve,
      ),
    );
    _animationController.forward(from: 0).then((_) {
      _isAnimating = false;
      _dragOffset = target;
    });
  }

  void _close() {
    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return ClipRRect(
      child: Stack(
        children: [
          /// ================= ACTION AREA (FIXED WIDTH) =================
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: maxOffset,
            child: Row(
              children: [
                // ⚠️ THỨ TỰ BẮT BUỘC: TRÁI → PHẢI (xa → gần)
                _actionTile(
                  color: Colors.purple,
                  icon: Iconsax.trash,
                  label: "Lưu trữ",
                  index: 2,
                  onTap: () {
                    _close();
                    widget.onDelete();
                  },
                ),
                _actionTile(
                  color: Colors.orange,
                  icon: Icons.push_pin,
                  label: "Ghim",
                  index: 1,
                  onTap: () {
                    _close();
                    widget.onPin();
                  },
                ),
                _actionTile(
                  color: Colors.red,
                  icon: Icons.more_horiz,
                  label: "Khác",
                  index: 0,
                  onTap: () {
                    _close();
                    widget.onMore();
                  },
                ),
              ],
            ),
          ),

          /// ================= MAIN ITEM =================
          GestureDetector(
            onHorizontalDragStart: (_) {
              if (_isAnimating) {
                _animationController.stop();
                _isAnimating = false;
                _dragOffset = _offsetAnimation.value;
              }
            },
            onHorizontalDragUpdate: (d) {
              _dragOffset = (_dragOffset + d.delta.dx).clamp(-maxOffset, 0);
              setState(() {});
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.velocity.pixelsPerSecond.dx;
              final current = _currentOffset;
              
              // Tính toán snap point dựa trên vị trí hiện tại và velocity
              double snapTarget;
              
              if (velocity < -500) {
                // Swipe nhanh sang trái → mở tối đa (3 tầng)
                snapTarget = -maxOffset;
              } else if (velocity > 500) {
                // Swipe nhanh sang phải → đóng
                snapTarget = 0;
              } else {
                // Snap theo vị trí (ngưỡng ở giữa mỗi tile)
                final threshold1 = -tileWidth * 0.5;  // Giữa 0 và tile 1
                final threshold2 = -tileWidth * 1.5; // Giữa tile 1 và tile 2
                final threshold3 = -tileWidth * 2.5; // Giữa tile 2 và tile 3
                
                if (current <= threshold3) {
                  // Vượt quá giữa tile 2 và 3 → snap đến 3 tầng
                  snapTarget = -maxOffset;
                } else if (current <= threshold2) {
                  // Vượt quá giữa tile 1 và 2 → snap đến 2 tầng
                  snapTarget = -tileWidth * 2;
                } else if (current <= threshold1) {
                  // Vượt quá giữa 0 và tile 1 → snap đến 1 tầng
                  snapTarget = -tileWidth;
                } else {
                  // Chưa đủ → đóng
                  snapTarget = 0;
                }
              }
              
              _animateTo(snapTarget);
            },
            onTap: () {
              if (_currentOffset != 0) _close();
            },
            child: Transform.translate(
              offset: Offset(_currentOffset, 0),
              child: Container(
                color: bg, // 🔴 BẮT BUỘC – che action phía sau
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ================= ACTION TILE WITH STACK EFFECT =================
  Widget _actionTile({
    required Color color,
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    // Vị trí bắt đầu của tile này (từ phải sang trái)
    final double revealStart = tileWidth * index;
    
    // Tính toán độ lệch để reveal tile
    // Khi _currentOffset = -revealStart - tileWidth, tile sẽ được reveal hoàn toàn
    final double revealProgress = 
        (-_currentOffset - revealStart) / tileWidth;
    
    // Clamp từ 0 đến 1 và tính dx để slide vào
    final double clampedProgress = revealProgress.clamp(0.0, 1.0);
    final double dx = (1.0 - clampedProgress) * tileWidth;

    return Transform.translate(
      offset: Offset(dx, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          child: Container(
            width: tileWidth,
            color: color,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
