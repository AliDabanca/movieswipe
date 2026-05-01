import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/repositories/social_repository.dart';
import '../models/social_models.dart';

class SocialRepositoryImpl implements SocialRepository {
  final ApiClient apiClient;

  SocialRepositoryImpl(this.apiClient);

  @override
  Future<Either<Failure, List<FriendEntity>>> getFriends() async {
    try {
      final response = await apiClient.get('/social/friends');
      final List<dynamic> data = response as List<dynamic>;
      return Right(data.map((json) => FriendModel.fromJson(json as Map<String, dynamic>)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> sendFriendRequest(String username) async {
    try {
      final response = await apiClient.post('/social/request/$username');
      final message = (response as Map<String, dynamic>)['message'] as String? ?? 'Sent';
      return Right(message);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FriendRequestEntity>>> getIncomingRequests() async {
    try {
      final response = await apiClient.get('/social/requests/incoming');
      final List<dynamic> data = response as List<dynamic>;
      return Right(data.map((json) => FriendRequestModel.fromJson(json as Map<String, dynamic>)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> acceptFriendRequest(String requestId) async {
    try {
      await apiClient.post('/social/accept/$requestId');
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> rejectFriendRequest(String requestId) async {
    try {
      await apiClient.post('/social/reject/$requestId');
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FriendProfileEntity>> getFriendProfile(String friendId) async {
    try {
      final response = await apiClient.get('/social/profile/$friendId');
      return Right(FriendProfileModel.fromJson(response as Map<String, dynamic>));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FriendEntity>>> searchUsers(String query) async {
    try {
      final response = await apiClient.get('/social/search/$query');
      final List<dynamic> data = response as List<dynamic>;
      return Right(data.map((json) => FriendModel.fromJson(json as Map<String, dynamic>)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
