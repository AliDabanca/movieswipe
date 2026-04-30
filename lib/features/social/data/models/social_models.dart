import '../../domain/entities/social_entities.dart';

/// Friend model — Data layer
class FriendModel extends FriendEntity {
  const FriendModel({
    required super.id,
    required super.username,
    super.displayName,
    super.avatarUrl,
    super.isFriend,
    super.isSelf,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isFriend: json['is_friend'] as bool? ?? false,
      isSelf: json['is_self'] as bool? ?? false,
    );
  }
}


/// Showcase movie model
class ShowcaseMovieModel extends ShowcaseMovieEntity {
  const ShowcaseMovieModel({
    required super.id,
    required super.name,
    super.posterPath,
    super.userRating,
  });

  factory ShowcaseMovieModel.fromJson(Map<String, dynamic> json) {
    return ShowcaseMovieModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      posterPath: json['poster_path'] as String?,
      userRating: json['user_rating'] as int?,
    );
  }
}

/// Compatibility model
class CompatibilityModel extends CompatibilityEntity {
  const CompatibilityModel({
    required super.score,
    required super.commonMovieCount,
    super.commonMovies,
    super.topOverlapGenres,
  });

  factory CompatibilityModel.fromJson(Map<String, dynamic> json) {
    return CompatibilityModel(
      score: json['compatibility_score'] as int? ?? 0,
      commonMovieCount: json['common_movie_count'] as int? ?? 0,
      commonMovies: (json['common_movies'] as List<dynamic>?)
              ?.map((e) => ShowcaseMovieModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topOverlapGenres: (json['top_overlap_genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Full friend profile model
class FriendProfileModel extends FriendProfileEntity {
  const FriendProfileModel({
    required super.friend,
    super.showcaseMovies,
    super.topGenres,
    super.compatibility,
  });

  factory FriendProfileModel.fromJson(Map<String, dynamic> json) {
    return FriendProfileModel(
      friend: FriendModel.fromJson(json['friend'] as Map<String, dynamic>),
      showcaseMovies: (json['showcase_movies'] as List<dynamic>?)
              ?.map((e) => ShowcaseMovieModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topGenres: (json['top_genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      compatibility: json['compatibility'] != null
          ? CompatibilityModel.fromJson(json['compatibility'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Friend request model
class FriendRequestModel extends FriendRequestEntity {
  const FriendRequestModel({
    required super.id,
    required super.sender,
    super.status,
    super.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String,
      sender: FriendModel.fromJson(json['profiles'] as Map<String, dynamic>),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
    );
  }
}
