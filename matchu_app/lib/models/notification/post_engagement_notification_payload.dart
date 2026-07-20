import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Payload shared by FCM and local notifications for aggregated post activity.
class PostEngagementNotificationPayload {
  static const String notificationType = 'post_engagement';

  const PostEngagementNotificationPayload({
    required this.postId,
    required this.title,
    required this.body,
    this.commentId,
    this.pendingCount = 1,
    this.likeCount = 0,
    this.commentCount = 0,
    this.deliveryMode = '',
  });

  final String postId;
  final String title;
  final String body;
  final String? commentId;
  final int pendingCount;
  final int likeCount;
  final int commentCount;
  final String deliveryMode;

  Map<String, dynamic> toJson() => {
    'type': notificationType,
    'postId': postId,
    'commentId': commentId,
    'pendingCount': pendingCount,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'deliveryMode': deliveryMode,
    'title': title,
    'body': body,
  };

  String toPayloadString() => jsonEncode(toJson());

  static PostEngagementNotificationPayload? fromRemoteMessage(
    RemoteMessage message,
  ) => fromJson(Map<String, dynamic>.from(message.data));

  static PostEngagementNotificationPayload? fromPayloadString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static PostEngagementNotificationPayload? fromJson(
    Map<String, dynamic> json,
  ) {
    if ((json['type'] ?? '').toString() != notificationType) return null;

    final postId = (json['postId'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final body = (json['body'] ?? '').toString().trim();
    if (postId.isEmpty || title.isEmpty || body.isEmpty) return null;

    return PostEngagementNotificationPayload(
      postId: postId,
      title: title,
      body: body,
      commentId: _nullableString(json['commentId']),
      pendingCount: _intValue(json['pendingCount'], fallback: 1),
      likeCount: _intValue(json['likeCount']),
      commentCount: _intValue(json['commentCount']),
      deliveryMode: (json['deliveryMode'] ?? '').toString().trim(),
    );
  }

  static String? _nullableString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
