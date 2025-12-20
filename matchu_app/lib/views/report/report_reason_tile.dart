import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import '../../../models/report_reason.dart';

class ReportReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  const ReportReasonTile({
    super.key,
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.errorColor.withOpacity(0.06)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.errorColor.withOpacity(0.4)
                : Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkBorder 
                            : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          children: [
            // ICON
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.errorColor.withOpacity(0.05)
                    : theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                reason.icon,
                color: selected
                    ? AppTheme.errorColor
                    : theme.colorScheme.onBackground,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // TEXT
            Expanded(
              child: Text(
                reason.title,
                style: theme.textTheme.bodyMedium,
              ),
            ),

            // RADIO
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? AppTheme.errorColor
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
