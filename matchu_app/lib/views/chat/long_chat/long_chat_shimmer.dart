import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/list_chat/shimmer/shimmer_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Header placeholder shown while the room is resolving the other participant.
class LongChatHeaderShimmer extends StatelessWidget {
  const LongChatHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ShimmerColors.of(context);

    return Shimmer.fromColors(
      baseColor: colors.base,
      highlightColor: colors.highlight,
      child: Row(
        children: [
          _ShimmerBlock(
            width: 46,
            height: 46,
            radius: 23,
            color: colors.surface,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShimmerBlock(
                width: 112,
                height: 14,
                radius: 7,
                color: colors.surface,
              ),
              const SizedBox(height: 7),
              _ShimmerBlock(
                width: 76,
                height: 11,
                radius: 6,
                color: colors.surface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mimics incoming and outgoing bubbles while the initial message stream loads.
class LongChatMessagesShimmer extends StatelessWidget {
  const LongChatMessagesShimmer({super.key});

  static const _bubbles = <_BubblePlaceholder>[
    _BubblePlaceholder(widthFactor: 0.48, height: 42, isMine: true),
    _BubblePlaceholder(widthFactor: 0.68, height: 58, isMine: false),
    _BubblePlaceholder(widthFactor: 0.36, height: 42, isMine: false),
    _BubblePlaceholder(widthFactor: 0.58, height: 74, isMine: true),
    _BubblePlaceholder(widthFactor: 0.44, height: 42, isMine: false),
    _BubblePlaceholder(widthFactor: 0.62, height: 58, isMine: true),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = ShimmerColors.of(context);

    return IgnorePointer(
      child: Shimmer.fromColors(
        baseColor: colors.base,
        highlightColor: colors.highlight,
        child: ListView.separated(
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          itemCount: _bubbles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final bubble = _bubbles[index];
            return Align(
              alignment:
                  bubble.isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: bubble.widthFactor,
                child: _ShimmerBlock(
                  width: double.infinity,
                  height: bubble.height,
                  radius: 18,
                  color: colors.surface,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _BubblePlaceholder {
  const _BubblePlaceholder({
    required this.widthFactor,
    required this.height,
    required this.isMine,
  });

  final double widthFactor;
  final double height;
  final bool isMine;
}
