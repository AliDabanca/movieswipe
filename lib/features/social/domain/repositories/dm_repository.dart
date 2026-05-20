import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dm_entities.dart';

abstract class DmRepository {
  Future<Either<Failure, MovieShareEntity>> shareMovie({
    required String receiverId,
    required int movieId,
  });

  Future<Either<Failure, List<MovieShareEntity>>> getHistory(String friendId);

  Future<Either<Failure, List<MovieDmItemEntity>>> getDmList();

  Future<Either<Failure, MovieShareEntity>> updateReaction({
    required String shareId,
    required String? reaction,
  });

  Future<Either<Failure, MovieShareEntity>> markAsViewed(String shareId);
}
