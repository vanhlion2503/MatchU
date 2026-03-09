import 'package:flutter/material.dart';

class VerifiedBadgeIcon extends StatelessWidget {
  const VerifiedBadgeIcon({
    super.key,
    this.size = 18,
    this.color = const Color(0xFF1D9BF0),
    this.padding = const EdgeInsets.only(left: 6),
  });

  final double size;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Icon(Icons.verified_rounded, size: size, color: color),
    );
  }
}

class VerifiedNameRow extends StatelessWidget {
  const VerifiedNameRow({
    super.key,
    required this.child,
    required this.isVerified,
    this.useFlexibleChild = true,
    this.mainAxisSize = MainAxisSize.max,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.badgeSize = 18,
    this.badgeColor = const Color(0xFF1D9BF0),
    this.badgePadding = const EdgeInsets.only(left: 6),
  });

  final Widget child;
  final bool isVerified;
  final bool useFlexibleChild;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double badgeSize;
  final Color badgeColor;
  final EdgeInsetsGeometry badgePadding;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (useFlexibleChild) Flexible(child: child) else child,
        if (isVerified)
          VerifiedBadgeIcon(
            size: badgeSize,
            color: badgeColor,
            padding: badgePadding,
          ),
      ],
    );
  }
}
