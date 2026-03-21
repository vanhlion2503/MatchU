import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

class ChatNotificationPayload {
  static const String notificationType = 'chat_message';

  final String roomId;
  final String senderUid;
  final String? senderName;
  final String? messageId;
  final String deliveryMode;
  final int pendingCount;
  final String? title;
  final String? body;

  const ChatNotificationPayload({
    required this.roomId,
    required this.senderUid,
    this.senderName,
    this.messageId,
    this.deliveryMode = '',
    this.pendingCount = 1,
    this.title,
    this.body,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': notificationType,
      'roomId': roomId,
      'senderUid': senderUid,
      'senderName': senderName,
      'messageId': messageId,
      'deliveryMode': deliveryMode,
      'pendingCount': pendingCount,
      'title': title,
      'body': body,
    };
  }

  Map<String, String> toMessageData() {
    final json = toJson();
    return json.map(
      (key, value) => MapEntry(key, value == null ? '' : value.toString()),
    );
  }

  String toPayloadString() => jsonEncode(toJson());

  ChatNotificationPayload copyWith({
    String? roomId,
    String? senderUid,
    String? senderName,
    String? messageId,
    String? deliveryMode,
    int? pendingCount,
    String? title,
    String? body,
  }) {
    return ChatNotificationPayload(
      roomId: roomId ?? this.roomId,
      senderUid: senderUid ?? this.senderUid,
      senderName: senderName ?? this.senderName,
      messageId: messageId ?? this.messageId,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      pendingCount: pendingCount ?? this.pendingCount,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  static ChatNotificationPayload? fromPayloadString(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) return null;
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static ChatNotificationPayload? fromRemoteMessage(RemoteMessage message) {
    return fromJson(Map<String, dynamic>.from(message.data));
  }

  static ChatNotificationPayload? fromJson(Map<String, dynamic> json) {
    if ((json['type'] ?? '').toString() != notificationType) {
      return null;
    }

    final roomId = (json['roomId'] ?? '').toString().trim();
    final senderUid = (json['senderUid'] ?? '').toString().trim();
    if (roomId.isEmpty || senderUid.isEmpty) {
      return null;
    }

    return ChatNotificationPayload(
      roomId: roomId,
      senderUid: senderUid,
      senderName: _readNullableString(json['senderName']),
      messageId: _readNullableString(json['messageId']),
      deliveryMode: (json['deliveryMode'] ?? '').toString(),
      pendingCount: _readInt(json['pendingCount']) ?? 1,
      title: _readNullableString(json['title']),
      body: _readNullableString(json['body']),
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
