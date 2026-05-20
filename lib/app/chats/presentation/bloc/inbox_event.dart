import 'package:equatable/equatable.dart';

abstract class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

class InboxLoadRequested extends InboxEvent {
  const InboxLoadRequested({this.refresh = false});

  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

class InboxFriendsLoadRequested extends InboxEvent {
  const InboxFriendsLoadRequested();
}
