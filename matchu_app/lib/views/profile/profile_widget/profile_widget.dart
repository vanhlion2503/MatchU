import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';


  Widget statItem(
    String value,
    String label,
    TextTheme textTheme, {
    VoidCallback? onTap,   // ✔ Named parameter
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Builder(
            builder: (context) {
              return Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget tabItem(String text, bool active, TextTheme textTheme) {
    return Column(
      children: [
        Builder(
          builder: (context) {
            return Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active
                    ? AppTheme.primaryColor
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            );
          },
        ),
        if (active)
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 3,
            width: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
      ],
    );
  }