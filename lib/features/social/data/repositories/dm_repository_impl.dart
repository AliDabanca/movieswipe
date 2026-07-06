import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dm_entities.dart';
import '../../domain/repositories/dm_repository.dart';
import '../models/dm_models.dart';

class DmRepositoryImpl implements DmRepository {
  final ApiClient apiClient;

  DmRepositoryImpl(this.apiClient);

  @override
  Future<Either<Failure, MovieShareEntity>> shareMovie({
    required String receiverId,
    required int movieId,
  }) async {
    try {
      final response = await apiClient.post('/dm/share', body: {
        'receiver_id': receiverId,
        'movie_id': movieId,
      });
      return Right(MovieShareModel.fromJson(response as Map<String, dynamic>));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MovieShareEntity>>> getHistory(String friendId) async {
    try {
      final response = await apiClient.get('/dm/history/$friendId');
      final List<dynamic> data = response as List<dynamic>;
      return Right(data.map((json) => MovieShareModel.fromJson(json as Map<String, dynamic>)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MovieDmItemEntity>>> getDmList() async {
    try {
      final response = await apiClient.get('/dm/list');
      final List<dynamic> data = response as List<dynamic>;
      return Right(data.map((json) => MovieDmItemModel.fromJson(json as Map<String, dynamic>)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MovieShareEntity>> updateReaction({
    required String shareId,
    required String? reaction,
  }) async {
    try {
      final response = await apiClient.patch('/dm/reaction/$shareId', body: {
        'reaction': reaction,
      });
      return Right(MovieShareModel.fromJson(response as Map<String, dynamic>));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MovieShareEntity>> markAsViewed(String shareId) async {
    try {
      final response = await apiClient.post('/dm/view/$shareId');
      return Right(MovieShareModel.fromJson(response as Map<String, dynamic>));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
