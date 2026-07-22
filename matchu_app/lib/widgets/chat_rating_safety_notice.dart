import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
import 'package:matchu_app/translations/chat_safety_translations.dart';

/// A non-blocking safety hint shared by temporary chat and video call.
class ChatRatingSafetyNotice extends StatelessWidget {
  const ChatRatingSafetyNotice({
    super.key,
    required this.summary,
    this.compact = false,
  });

  final ChatPeerSummary? summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (summary?.shouldShowSafetyCaution != true) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    const accent = Color(0xFFFFB020);
    final title = ChatSafetyTranslationKeys.cautionTitle.tr;
    final body = ChatSafetyTranslationKeys.cautionBody.tr;

    return Semantics(
      label: '$title. $body',
      child: Tooltip(
        message: body,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 12,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color:
                compact
                    ? Colors.black.withValues(alpha: 0.56)
                    : accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(compact ? 14 : 12),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              const Icon(Icons.shield_outlined, color: accent, size: 17),
              const SizedBox(width: 7),
              if (compact)
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
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
