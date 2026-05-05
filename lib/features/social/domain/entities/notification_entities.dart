import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String userId;
  final String actorId;
  final String type;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;
  final String? actorUsername;
  final String? actorDisplayName;
  final String? actorAvatarUrl;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.actorUsername,
    this.actorDisplayName,
    this.actorAvatarUrl,
  });

  @override
  List<Object?> get props => [id, userId, actorId, type, relatedId, isRead, createdAt];
}
