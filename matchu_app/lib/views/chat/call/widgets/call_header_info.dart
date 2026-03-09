import 'package:flutter/material.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class CallHeaderInfo extends StatelessWidget {
  const CallHeaderInfo({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isVerified,
  });

  final String title;
  final String subtitle;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        VerifiedNameRow(
          isVerified: isVerified,
          mainAxisSize: MainAxisSize.min,
          useFlexibleChild: false,
          badgeColor: Colors.white,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
