import 'package:equatable/equatable.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'social_entities.dart';

/// Direct movie share entity
class MovieShareEntity extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final int movieId;
  final String? reaction; // Emoji like ❤️, 🍿, 🔥, 👍
  final DateTime createdAt;
  final bool isViewed;
  final Movie? movie;

  const MovieShareEntity({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.movieId,
    this.reaction,
    required this.createdAt,
    required this.isViewed,
    this.movie,
  });

  @override
  List<Object?> get props => [id, senderId, receiverId, movieId, reaction, createdAt, isViewed, movie];
}

/// Movie DM List Item entity
class MovieDmItemEntity extends Equatable {
  final FriendEntity friend;
  final MovieShareEntity? lastShare;
  final int unreadCount;
  final int shareStreak;

  const MovieDmItemEntity({
    required this.friend,
    this.lastShare,
    this.unreadCount = 0,
    required this.shareStreak,
  });

  @override
  List<Object?> get props => [friend, lastShare, unreadCount, shareStreak];
}
