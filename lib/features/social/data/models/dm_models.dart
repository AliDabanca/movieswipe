import '../../domain/entities/dm_entities.dart';
import 'social_models.dart';
import '../../../movies/data/models/movie_model.dart';

class MovieShareModel extends MovieShareEntity {
  const MovieShareModel({
    required super.id,
    required super.senderId,
    required super.receiverId,
    required super.movieId,
    super.reaction,
    required super.createdAt,
    required super.isViewed,
    super.movie,
  });

  factory MovieShareModel.fromJson(Map<String, dynamic> json) {
    return MovieShareModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      movieId: json['movie_id'] as int,
      reaction: json['reaction'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isViewed: json['is_viewed'] as bool? ?? false,
      movie: json['movie'] != null
          ? MovieModel.fromJson(json['movie'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MovieDmItemModel extends MovieDmItemEntity {
  const MovieDmItemModel({
    required super.friend,
    super.lastShare,
    super.unreadCount,
    required super.shareStreak,
  });

  factory MovieDmItemModel.fromJson(Map<String, dynamic> json) {
    return MovieDmItemModel(
      friend: FriendModel.fromJson(json['friend'] as Map<String, dynamic>),
      lastShare: json['last_share'] != null
          ? MovieShareModel.fromJson(json['last_share'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      shareStreak: json['share_streak'] as int? ?? 0,
    );
  }
}
