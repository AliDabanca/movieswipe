import 'package:equatable/equatable.dart';

abstract class DmEvent extends Equatable {
  const DmEvent();

  @override
  List<Object?> get props => [];
}

class LoadDmListEvent extends DmEvent {}

class LoadDmHistoryEvent extends DmEvent {
  final String friendId;

  const LoadDmHistoryEvent(this.friendId);

  @override
  List<Object?> get props => [friendId];
}

class ShareMovieEvent extends DmEvent {
  final String receiverId;
  final int movieId;

  const ShareMovieEvent({
    required this.receiverId,
    required this.movieId,
  });

  @override
  List<Object?> get props => [receiverId, movieId];
}

class UpdateReactionEvent extends DmEvent {
  final String shareId;
  final String? reaction;
  final String friendId;

  const UpdateReactionEvent({
    required this.shareId,
    required this.reaction,
    required this.friendId,
  });

  @override
  List<Object?> get props => [shareId, reaction, friendId];
}

class MarkAsViewedEvent extends DmEvent {
  final String shareId;
  final String friendId;

  const MarkAsViewedEvent({
    required this.shareId,
    required this.friendId,
  });

  @override
  List<Object?> get props => [shareId, friendId];
}
