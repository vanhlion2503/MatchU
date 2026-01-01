import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/list_chat/shimmer/shimmer_colors.dart';
import 'package:shimmer/shimmer.dart';

class ChatItemShimmer extends StatelessWidget {
  const ChatItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final shimmer = ShimmerColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          /// AVATAR
          Shimmer.fromColors(
            baseColor: shimmer.base,
            highlightColor: shimmer.highlight,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: shimmer.surface,
            ),
          ),

          const SizedBox(width: 12),

          /// NAME + MESSAGE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, shimmer, width: 120),
                const SizedBox(height: 8),
                _line(context, shimmer, width: double.infinity),
              ],
            ),
          ),

          const SizedBox(width: 12),

          /// TIME + BADGE
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _line(context, shimmer, width: 40, height: 12),
              const SizedBox(height: 12),
              _line(context, shimmer,
                  width: 18, height: 18, radius: 9),
            ],
          )
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    ShimmerColors shimmer, {
    required double width,
    double height = 14,
    double radius = 6,
  }) {
    return Shimmer.fromColors(
      baseColor: shimmer.base,
      highlightColor: shimmer.highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmer.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
