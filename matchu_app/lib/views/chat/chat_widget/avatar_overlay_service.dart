import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'anonymous_avatar_selector.dart';

class AvatarOverlayService {
  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    if (_entry != null) return;

    final overlay = _resolveOverlay(context);
    if (overlay == null) {
      debugPrint('AvatarOverlayService: no overlay available');
      return;
    }

    _entry = OverlayEntry(
      builder: (_) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: hide,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              const AnonymousAvatarSelector(),
            ],
          ),
        );
      },
    );

    overlay.insert(_entry!);
  }

  static OverlayState? _resolveOverlay(BuildContext context) {
    final navigatorOverlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (navigatorOverlay != null) {
      return navigatorOverlay;
    }

    final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
    if (rootOverlay != null) {
      return rootOverlay;
    }

    return Get.key.currentState?.overlay;
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}
