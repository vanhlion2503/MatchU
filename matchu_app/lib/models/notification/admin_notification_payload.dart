import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

class AdminNotificationPayload {
  static const String notificationType = 'admin_campaign';

  const AdminNotificationPayload({
    required this.campaignId,
    required this.category,
    required this.title,
    required this.body,
    this.actionType = 'inbox',
    this.actionValue = '',
    this.deliveryMode = '',
  });

  final String campaignId;
  final String category;
  final String title;
  final String body;
  final String actionType;
  final String actionValue;
  final String deliveryMode;

  Map<String, dynamic> toJson() => {
    'type': notificationType,
    'campaignId': campaignId,
    'category': category,
    'title': title,
    'body': body,
    'actionType': actionType,
    'actionValue': actionValue,
    'deliveryMode': deliveryMode,
  };

  String toPayloadString() => jsonEncode(toJson());

  static AdminNotificationPayload? fromRemoteMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if ((data['title'] ?? '').toString().trim().isEmpty) {
      data['title'] = message.notification?.title;
    }
    if ((data['body'] ?? '').toString().trim().isEmpty) {
      data['body'] = message.notification?.body;
    }
    return fromJson(data);
  }

  static AdminNotificationPayload? fromPayloadString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static AdminNotificationPayload? fromJson(Map<String, dynamic> json) {
    if ((json['type'] ?? '').toString().trim() != notificationType) return null;
    final campaignId = (json['campaignId'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final body = (json['body'] ?? '').toString().trim();
    if (campaignId.isEmpty || title.isEmpty || body.isEmpty) return null;
    return AdminNotificationPayload(
      campaignId: campaignId,
      category: (json['category'] ?? 'general').toString().trim(),
      title: title,
      body: body,
      actionType: (json['actionType'] ?? 'inbox').toString().trim(),
      actionValue: (json['actionValue'] ?? '').toString().trim(),
      deliveryMode: (json['deliveryMode'] ?? '').toString().trim(),
    );
  }
}
