import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/social_entities.dart';
import '../entities/notification_entities.dart';

/// Abstract repository for social features
abstract class SocialRepository {
  Future<Either<Failure, List<FriendEntity>>> getFriends();
  Future<Either<Failure, String>> sendFriendRequest(String username);
  Future<Either<Failure, List<FriendRequestEntity>>> getIncomingRequests();
  Future<Either<Failure, Unit>> acceptFriendRequest(String requestId);
  Future<Either<Failure, Unit>> rejectFriendRequest(String requestId);
  Future<Either<Failure, FriendProfileEntity>> getFriendProfile(String friendId);
  Future<Either<Failure, List<FriendEntity>>> searchUsers(String query);
  Future<Either<Failure, int>> getFriendCount(String userId);
  Future<Either<Failure, List<NotificationEntity>>> getNotifications();
  Future<Either<Failure, Unit>> markNotificationAsRead(String notificationId);
}
