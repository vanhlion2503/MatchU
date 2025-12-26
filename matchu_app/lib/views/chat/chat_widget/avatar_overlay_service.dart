import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'anonymous_avatar_selector.dart';

class AvatarOverlayService {
  static OverlayEntry? _entry;

  static void show() {
    if (_entry != null) return;

    final overlayContext = Get.overlayContext;
    if (overlayContext == null) {
      debugPrint("❌ No overlay context found");
      return;
    }

    _entry = OverlayEntry(
      builder: (_) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              GestureDetector(
                onTap: hide,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
              ),
              const AnonymousAvatarSelector(),
            ],
          ),
        );
      },
    );

    Overlay.of(overlayContext).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

