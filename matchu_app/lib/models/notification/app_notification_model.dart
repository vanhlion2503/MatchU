import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  postLike,
  postComment,
  moderationPenalty,
  systemAnnouncement,
  maintenance,
  appUpdate,
  policyUpdate,
  unknown;

  static AppNotificationType fromValue(dynamic value) {
    switch (value?.toString().trim()) {
      case 'post_like':
        return AppNotificationType.postLike;
      case 'post_comment':
        return AppNotificationType.postComment;
      case 'moderation_penalty':
        return AppNotificationType.moderationPenalty;
      case 'system_announcement':
        return AppNotificationType.systemAnnouncement;
      case 'maintenance':
        return AppNotificationType.maintenance;
      case 'app_update':
        return AppNotificationType.appUpdate;
      case 'policy_update':
        return AppNotificationType.policyUpdate;
      default:
        return AppNotificationType.unknown;
    }
  }
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.actorId,
    this.actorName,
    this.actorNickname,
    this.actorAvatarUrl,
    this.postId,
    this.commentId,
    this.reason,
    this.severity,
    this.penalty,
    this.reputationBefore,
    this.reputationAfter,
    this.campaignId,
    this.category,
    this.actionType,
    this.actionValue,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;
  final String? actorId;
  final String? actorName;
  final String? actorNickname;
  final String? actorAvatarUrl;
  final String? postId;
  final String? commentId;
  final String? reason;
  final String? severity;
  final int? penalty;
  final int? reputationBefore;
  final int? reputationAfter;
  final String? campaignId;
  final String? category;
  final String? actionType;
  final String? actionValue;

  bool get isUnread => readAt == null;
  bool get hasActorAvatar => (actorAvatarUrl ?? '').trim().isNotEmpty;
  bool get canOpenPost => (postId ?? '').trim().isNotEmpty;

  factory AppNotificationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotificationModel(
      id: doc.id,
      type: AppNotificationType.fromValue(data['type']),
      title: (data['title'] ?? '').toString().trim(),
      body: (data['body'] ?? '').toString().trim(),
      createdAt: _parseDateTime(data['createdAt']),
      readAt: _parseDateTime(data['readAt']),
      actorId: _parseNullableString(data['actorId']),
      actorName: _parseNullableString(data['actorName']),
      actorNickname: _parseNullableString(data['actorNickname']),
      actorAvatarUrl: _parseNullableString(data['actorAvatarUrl']),
      postId: _parseNullableString(data['postId']),
      commentId: _parseNullableString(data['commentId']),
      reason: _parseNullableString(data['reason']),
      severity: _parseNullableString(data['severity']),
      penalty: _parseInt(data['penalty']),
      reputationBefore: _parseInt(data['reputationBefore']),
      reputationAfter: _parseInt(data['reputationAfter']),
      campaignId: _parseNullableString(data['campaignId']),
      category: _parseNullableString(data['category']),
      actionType: _parseNullableString(data['actionType']),
      actionValue: _parseNullableString(data['actionValue']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
