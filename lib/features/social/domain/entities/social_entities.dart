import 'package:equatable/equatable.dart';

/// Friend profile entity
class FriendEntity extends Equatable {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isFriend;
  final bool isSelf;

  const FriendEntity({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.isFriend = false,
    this.isSelf = false,
  });

  @override
  List<Object?> get props => [id, username, displayName, avatarUrl, isFriend, isSelf];
}

/// A movie in a friend's showcase

class ShowcaseMovieEntity extends Equatable {
  final int id;
  final String name;
  final String? posterPath;
  final int? userRating;

  const ShowcaseMovieEntity({
    required this.id,
    required this.name,
    this.posterPath,
    this.userRating,
  });

  @override
  List<Object?> get props => [id, name, posterPath, userRating];
}

/// Compatibility analysis between current user and a friend
class CompatibilityEntity extends Equatable {
  final int score;
  final int commonMovieCount;
  final List<ShowcaseMovieEntity> commonMovies;
  final List<String> topOverlapGenres;

  const CompatibilityEntity({
    required this.score,
    required this.commonMovieCount,
    this.commonMovies = const [],
    this.topOverlapGenres = const [],
  });

  @override
  List<Object?> get props => [score, commonMovieCount, commonMovies, topOverlapGenres];
}

/// Full friend profile with all social data
class FriendProfileEntity extends Equatable {
  final FriendEntity friend;
  final List<ShowcaseMovieEntity> showcaseMovies;
  final List<String> topGenres;
  final CompatibilityEntity? compatibility;

  const FriendProfileEntity({
    required this.friend,
    this.showcaseMovies = const [],
    this.topGenres = const [],
    this.compatibility,
  });

  @override
  List<Object?> get props => [friend, showcaseMovies, topGenres, compatibility];
}

/// A friend request
class FriendRequestEntity extends Equatable {
  final String id;
  final FriendEntity sender;
  final String status;
  final String? createdAt;

  const FriendRequestEntity({
    required this.id,
    required this.sender,
    this.status = 'pending',
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, sender, status, createdAt];
}
