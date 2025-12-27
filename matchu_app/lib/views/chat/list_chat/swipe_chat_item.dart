import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/theme/app_theme.dart';

class SwipeChatItem extends StatefulWidget {
  final Widget child;
  final ChatRoomModel room;
  final String uid;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const SwipeChatItem({
    super.key,
    required this.child,
    required this.room,
    required this.uid,
    required this.onPin,
    required this.onDelete,
  });

  @override
  State<SwipeChatItem> createState() => _SwipeChatItemState();
}

class _SwipeChatItemState extends State<SwipeChatItem>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  Animation<double>? _animation; 

  double _dx = 0;
  static const double maxSlide = 120;

  @override
  void initState(){
    super.initState();

    _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  }
  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dx += d.delta.dx;
      _dx = _dx.clamp(-maxSlide, 0);
    });
  }

  void _onDragEnd(_) {
    final bool shouldOpen = _dx < -maxSlide / 2;
    final double target = shouldOpen ? -maxSlide : 0.0;

    _controller.stop();
    _controller.reset();

    _animation = Tween<double>(
      begin: _dx,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        setState(() {
          _dx = _animation!.value;
        });
      });

    _controller.forward();
  }

  void _close() {
    _controller.stop();
    _controller.reset();

    _animation = Tween<double>(
      begin: _dx,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        setState(() {
          _dx = _animation!.value;
        });
      });

    _controller.forward();
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect( // 🔴 QUAN TRỌNG
      child: Stack(
        children: [
          /// ACTIONS (RIGHT SIDE)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: maxSlide,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: widget.room.isPinned(widget.uid)
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: AppTheme.primaryColor,
                      onTap: () {
                        _close();
                        widget.onPin();
                      },
                    ),
                    _ActionButton(
                      icon: Iconsax.trash,
                      color: AppTheme.errorColor,
                      onTap: () {
                        _close();
                        widget.onDelete();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          /// MAIN CONTENT
          Transform.translate(
            offset: Offset(_dx, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTap: () {
                if (_dx != 0) _close();
              },
              child: Container(
                width: double.infinity,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: widget.child,
              ),
            ),
          ),

        ],
      ),
    );
  }
}



class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color),
      ),
    );
  }
}