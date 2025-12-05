import 'package:flutter/material.dart';

Widget lightningIcon() {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1F2937), // xám đậm
          Color(0xFF111827), // xám rất đậm
        ],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.flash_on, // ⚡ icon tia sét
        size: 20,
        color: Colors.white,
      ),
    ),
  );
}
