import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum PostNativeShareStatus { success, dismissed, unavailable }

abstract interface class PostShareRepository {
  Future<PostNativeShareStatus> share({
    required String title,
    required String text,
    Rect? sharePositionOrigin,
  });

  Future<void> copyText(String text);
}

class PlatformPostShareRepository implements PostShareRepository {
  @override
  Future<PostNativeShareStatus> share({
    required String title,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        subject: title,
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return switch (result.status) {
      ShareResultStatus.success => PostNativeShareStatus.success,
      ShareResultStatus.dismissed => PostNativeShareStatus.dismissed,
      ShareResultStatus.unavailable => PostNativeShareStatus.unavailable,
    };
  }

  @override
  Future<void> copyText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
