import 'package:equatable/equatable.dart';
import '../../domain/entities/social_entities.dart';

abstract class SocialState extends Equatable {
  const SocialState();
  @override
  List<Object?> get props => [];
}

class SocialInitial extends SocialState {}

class SocialLoading extends SocialState {}

class FriendsLoaded extends SocialState {
  final List<FriendEntity> friends;
  const FriendsLoaded(this.friends);
  @override
  List<Object?> get props => [friends];
}

class IncomingRequestsLoaded extends SocialState {
  final List<FriendRequestEntity> requests;
  const IncomingRequestsLoaded(this.requests);
  @override
  List<Object?> get props => [requests];
}

class UserSearchResults extends SocialState {
  final List<FriendEntity> results;
  const UserSearchResults(this.results);
  @override
  List<Object?> get props => [results];
}

class FriendProfileLoaded extends SocialState {
  final FriendProfileEntity profile;
  const FriendProfileLoaded(this.profile);
  @override
  List<Object?> get props => [profile];
}

class SocialSuccess extends SocialState {
  final String message;
  const SocialSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SocialError extends SocialState {
  final String message;
  const SocialError(this.message);
  @override
  List<Object?> get props => [message];
}
