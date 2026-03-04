import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum CallMessageBubbleType { missed, incoming, outgoing }

class CallMessageBubble extends StatelessWidget {
  final String title;
  final String time;
  final VoidCallback? onRecallPressed;
  final CallMessageBubbleType callType;
  final bool isVideoCall;
  final bool isSuccessful;
  final bool isMe;

  const CallMessageBubble({
    super.key,
    required this.title,
    required this.time,
    required this.onRecallPressed,
    required this.callType,
    required this.isVideoCall,
    required this.isSuccessful,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMissed = callType == CallMessageBubbleType.missed;
    final iconBackground = _resolveIconBackground(colorScheme);
    final iconColor = _resolveIconForeground(colorScheme);
    final titleColor =
        isMe
            ? colorScheme.onPrimary
            : (isMissed ? colorScheme.error : colorScheme.onSurface);
    final subtitleColor =
        isMe
            ? colorScheme.onPrimary.withValues(alpha: 0.72)
            : colorScheme.onSurface.withValues(alpha: 0.72);
    final recallButtonColor =
        isMe
            ? AppTheme.secondaryColor
            : AppTheme.primaryColor;
    final recallLabel = isVideoCall ? "Gọi video lại" : "Gọi lại";

    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: titleColor,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: subtitleColor,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBackground,
              ),
              child: Center(
                child: SvgPicture.asset(
                  _resolveCallIcon(),
                  width: 26,
                  height: 26,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(time, style: subtitleStyle),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            onPressed: onRecallPressed,
            style: FilledButton.styleFrom(
              backgroundColor: recallButtonColor,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              recallLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _resolveCallIcon() {
    if (isVideoCall) {
      if (callType == CallMessageBubbleType.missed) {
        return "assets/icon/video-slash.svg";
      }
      return "assets/icon/video.svg";
    }

    if (callType == CallMessageBubbleType.missed) {
      return "assets/icon/call-remove.svg";
    }
    if (isSuccessful) {
      return "assets/icon/call-received.svg";
    }
    if (callType == CallMessageBubbleType.incoming) {
      return "assets/icon/call-received.svg";
    }
    return "assets/icon/call-remove.svg";
  }

  Color _resolveIconBackground(ColorScheme colorScheme) {
    if (isVideoCall) {
      return colorScheme.secondary; // videocall
    }
    return AppTheme.errorColor; // call thường
  }

  Color _resolveIconForeground(ColorScheme colorScheme) {
    if (callType == CallMessageBubbleType.missed) {
      return colorScheme.onError;
    }
    if (isSuccessful) {
      return colorScheme.onPrimary;
    }
    if (isVideoCall) {
      return colorScheme.onSecondary;
    }
    return colorScheme.onPrimary;
  }
}
