import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

Widget genderIcon(String? gender, ThemeData theme) {
  if (gender == null) return const SizedBox();

  IconData icon;
  Color color;

  switch (gender) {
    case "male":
      icon = Iconsax.man;
      color = Colors.blueAccent;
      break;
    case "female":
      icon = Iconsax.woman;
      color = Colors.pinkAccent;
      break;
    default:
      return const SizedBox();
  }

  return Icon(
    icon,
    size: 16,
    color: color,
  );
}
