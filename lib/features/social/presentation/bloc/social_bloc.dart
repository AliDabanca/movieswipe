import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/social_repository.dart';
import 'social_event.dart';
import 'social_state.dart';

class SocialBloc extends Bloc<SocialEvent, SocialState> {
  final SocialRepository repository;

  SocialBloc({required this.repository}) : super(SocialInitial()) {
    on<LoadFriendsEvent>(_onLoadFriends);
    on<LoadIncomingRequestsEvent>(_onLoadIncomingRequests);
    on<SendFriendRequestEvent>(_onSendRequest);
    on<AcceptRequestEvent>(_onAcceptRequest);
    on<RejectRequestEvent>(_onRejectRequest);
    on<SearchUsersEvent>(_onSearchUsers);
    on<LoadFriendProfileEvent>(_onLoadFriendProfile);
    on<LoadFriendCountEvent>(_onLoadFriendCount);
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<MarkNotificationReadEvent>(_onMarkNotificationRead);
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.getNotifications();
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (notifications) => emit(NotificationsLoaded(notifications)),
    );
  }

  Future<void> _onMarkNotificationRead(
    MarkNotificationReadEvent event,
    Emitter<SocialState> emit,
  ) async {
    await repository.markNotificationAsRead(event.notificationId);
    // Silent update or reload? Usually silent is fine for 'read' status
    add(LoadNotificationsEvent());
  }

  Future<void> _onLoadFriendCount(
    LoadFriendCountEvent event,
    Emitter<SocialState> emit,
  ) async {
    final result = await repository.getFriendCount(event.userId);
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (count) => emit(FriendCountLoaded(count)),
    );
  }

  Future<void> _onLoadFriends(
    LoadFriendsEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.getFriends();
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (friends) {
        emit(FriendsLoaded(friends));
        emit(FriendCountLoaded(friends.length));
      },
    );
  }

  Future<void> _onLoadIncomingRequests(
    LoadIncomingRequestsEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.getIncomingRequests();
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (requests) => emit(IncomingRequestsLoaded(requests)),
    );
  }

  Future<void> _onSendRequest(
    SendFriendRequestEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.sendFriendRequest(event.username);
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (message) {
        emit(SocialSuccess(message));
      },
    );
  }

  Future<void> _onAcceptRequest(
    AcceptRequestEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.acceptFriendRequest(event.requestId);
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {
        emit(const SocialSuccess('Arkadaşlık isteği kabul edildi!'));
        // Reload both lists
        add(LoadFriendsEvent());
        add(LoadIncomingRequestsEvent());
      },
    );
  }

  Future<void> _onRejectRequest(
    RejectRequestEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.rejectFriendRequest(event.requestId);
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {
        emit(const SocialSuccess('İstek reddedildi.'));
        add(LoadIncomingRequestsEvent());
      },
    );
  }

  Future<void> _onSearchUsers(
    SearchUsersEvent event,
    Emitter<SocialState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(const UserSearchResults([]));
      return;
    }
    emit(SocialLoading());
    final result = await repository.searchUsers(event.query);
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (results) => emit(UserSearchResults(results)),
    );
  }

  Future<void> _onLoadFriendProfile(
    LoadFriendProfileEvent event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());
    final result = await repository.getFriendProfile(event.friendId);
    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (profile) => emit(FriendProfileLoaded(profile)),
    );
  }
}
