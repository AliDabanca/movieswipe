import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/dm_repository.dart';
import 'dm_event.dart';
import 'dm_state.dart';

class DmBloc extends Bloc<DmEvent, DmState> {
  final DmRepository repository;

  DmBloc({required this.repository}) : super(DmInitial()) {
    on<LoadDmListEvent>(_onLoadDmList);
    on<LoadDmHistoryEvent>(_onLoadDmHistory);
    on<ShareMovieEvent>(_onShareMovie);
    on<UpdateReactionEvent>(_onUpdateReaction);
    on<MarkAsViewedEvent>(_onMarkAsViewed);
  }

  Future<void> _onLoadDmList(
    LoadDmListEvent event,
    Emitter<DmState> emit,
  ) async {
    emit(DmLoading());
    final result = await repository.getDmList();
    result.fold(
      (failure) => emit(DmError(failure.message)),
      (dmList) => emit(DmListLoaded(dmList)),
    );
  }

  Future<void> _onLoadDmHistory(
    LoadDmHistoryEvent event,
    Emitter<DmState> emit,
  ) async {
    emit(DmLoading());
    final result = await repository.getHistory(event.friendId);
    result.fold(
      (failure) => emit(DmError(failure.message)),
      (history) => emit(DmHistoryLoaded(history)),
    );
  }

  Future<void> _onShareMovie(
    ShareMovieEvent event,
    Emitter<DmState> emit,
  ) async {
    emit(DmLoading());
    final result = await repository.shareMovie(
      receiverId: event.receiverId,
      movieId: event.movieId,
    );
    result.fold(
      (failure) => emit(DmError(failure.message)),
      (share) {
        emit(DmShareSuccess(share));
        // Automatically reload history
        add(LoadDmHistoryEvent(event.receiverId));
      },
    );
  }

  Future<void> _onUpdateReaction(
    UpdateReactionEvent event,
    Emitter<DmState> emit,
  ) async {
    final result = await repository.updateReaction(
      shareId: event.shareId,
      reaction: event.reaction,
    );
    result.fold(
      (failure) => emit(DmError(failure.message)),
      (_) {
        // Automatically reload history
        add(LoadDmHistoryEvent(event.friendId));
      },
    );
  }

  Future<void> _onMarkAsViewed(
    MarkAsViewedEvent event,
    Emitter<DmState> emit,
  ) async {
    final result = await repository.markAsViewed(event.shareId);
    result.fold(
      (failure) => emit(DmError(failure.message)),
      (_) {
        // Automatically reload history
        add(LoadDmHistoryEvent(event.friendId));
      },
    );
  }
}
