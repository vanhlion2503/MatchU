import 'package:flutter/material.dart';

class ReactionIcon {
  final String id;            // dùng để lưu DB
  final Widget icon;          // UI hiển thị

  ReactionIcon({
    required this.id,
    required this.icon,
  });
}
