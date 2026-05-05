import '../../domain/entities/notification_entities.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.actorId,
    required super.type,
    super.relatedId,
    required super.isRead,
    required super.createdAt,
    super.actorUsername,
    super.actorDisplayName,
    super.actorAvatarUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['profiles'] as Map<String, dynamic>?;
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      actorId: json['actor_id'],
      type: json['type'],
      relatedId: json['related_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      actorUsername: actor?['username'],
      actorDisplayName: actor?['display_name'],
      actorAvatarUrl: actor?['avatar_url'],
    );
  }
}
