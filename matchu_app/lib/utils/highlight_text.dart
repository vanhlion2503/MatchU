import 'package:flutter/material.dart';

TextSpan highlightText({
  required String text,
  required String query,
  required TextStyle normalStyle,
  required TextStyle highlightStyle,
}) {
  if (query.isEmpty) {
    return TextSpan(text: text, style: normalStyle);
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();

  final spans = <TextSpan>[];
  int start = 0;

  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: normalStyle,
        ),
      );
      break;
    }

    if (index > start) {
      spans.add(
        TextSpan(
          text: text.substring(start, index),
          style: normalStyle,
        ),
      );
    }

    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle,
      ),
    );

    start = index + query.length;
  }

  return TextSpan(children: spans);
}
