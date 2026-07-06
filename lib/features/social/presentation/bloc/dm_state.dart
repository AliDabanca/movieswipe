import 'package:equatable/equatable.dart';
import '../../domain/entities/dm_entities.dart';

abstract class DmState extends Equatable {
  const DmState();

  @override
  List<Object?> get props => [];
}

class DmInitial extends DmState {}

class DmLoading extends DmState {}

class DmListLoaded extends DmState {
  final List<MovieDmItemEntity> dmList;

  const DmListLoaded(this.dmList);

  @override
  List<Object?> get props => [dmList];
}

class DmHistoryLoaded extends DmState {
  final List<MovieShareEntity> history;

  const DmHistoryLoaded(this.history);

  @override
  List<Object?> get props => [history];
}

class DmShareSuccess extends DmState {
  final MovieShareEntity share;

  const DmShareSuccess(this.share);

  @override
  List<Object?> get props => [share];
}

class DmError extends DmState {
  final String message;

  const DmError(this.message);

  @override
  List<Object?> get props => [message];
}
