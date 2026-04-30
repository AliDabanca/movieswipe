import 'package:equatable/equatable.dart';

abstract class SocialEvent extends Equatable {
  const SocialEvent();
  @override
  List<Object?> get props => [];
}

class LoadFriendsEvent extends SocialEvent {}

class LoadIncomingRequestsEvent extends SocialEvent {}

class SendFriendRequestEvent extends SocialEvent {
  final String username;
  const SendFriendRequestEvent(this.username);
  @override
  List<Object?> get props => [username];
}

class AcceptRequestEvent extends SocialEvent {
  final String requestId;
  const AcceptRequestEvent(this.requestId);
  @override
  List<Object?> get props => [requestId];
}

class RejectRequestEvent extends SocialEvent {
  final String requestId;
  const RejectRequestEvent(this.requestId);
  @override
  List<Object?> get props => [requestId];
}

class SearchUsersEvent extends SocialEvent {
  final String query;
  const SearchUsersEvent(this.query);
  @override
  List<Object?> get props => [query];
}

class LoadFriendProfileEvent extends SocialEvent {
  final String friendId;
  const LoadFriendProfileEvent(this.friendId);
  @override
  List<Object?> get props => [friendId];
}
