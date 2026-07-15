import 'package:equatable/equatable.dart';

class ChatPollVoteEntity extends Equatable {
  const ChatPollVoteEntity({
    required this.optionIndex,
    required this.userId,
  });

  final int optionIndex;
  final String userId;

  @override
  List<Object?> get props => [optionIndex, userId];
}

class ChatPollEntity extends Equatable {
  const ChatPollEntity({
    required this.question,
    required this.options,
    this.allowMultiple = false,
    this.endsAt,
    this.totalVotes = 0,
    this.counts = const [],
    this.votes = const [],
  });

  final String question;
  final List<String> options;
  final bool allowMultiple;
  final DateTime? endsAt;
  final int totalVotes;
  final List<int> counts;
  final List<ChatPollVoteEntity> votes;

  bool get hasEnded {
    final end = endsAt;
    if (end == null) return false;
    return DateTime.now().isAfter(end.toLocal());
  }

  int? voteOptionForUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    for (final vote in votes) {
      if (vote.userId == id) return vote.optionIndex;
    }
    return null;
  }

  double optionPercent(int index) {
    if (totalVotes <= 0 || index < 0 || index >= counts.length) return 0;
    return counts[index] / totalVotes;
  }

  factory ChatPollEntity.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final countsRaw = json['counts'];
    final counts = countsRaw is List
        ? countsRaw.map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? 0).toList()
        : List<int>.filled(options.length, 0);

    final votesRaw = json['votes'];
    final votes = <ChatPollVoteEntity>[];
    if (votesRaw is List) {
      for (final item in votesRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final index = map['optionIndex'] ?? map['option_index'];
        final userId = (map['userId'] ?? map['user_id'] ?? '').toString();
        final parsedIndex = index is num
            ? index.toInt()
            : int.tryParse(index?.toString() ?? '');
        if (parsedIndex == null || userId.isEmpty) continue;
        votes.add(
          ChatPollVoteEntity(optionIndex: parsedIndex, userId: userId),
        );
      }
    }

    DateTime? endsAt;
    final endsRaw = json['endsAt'] ?? json['ends_at'];
    if (endsRaw != null) {
      endsAt = DateTime.tryParse(endsRaw.toString());
    }

    final total = json['totalVotes'] ?? json['total_votes'];
    final totalVotes = total is num
        ? total.toInt()
        : int.tryParse(total?.toString() ?? '') ??
            counts.fold<int>(0, (a, b) => a + b);

    return ChatPollEntity(
      question: (json['question'] ?? '').toString(),
      options: options,
      allowMultiple: json['allowMultiple'] == true || json['allow_multiple'] == true,
      endsAt: endsAt,
      totalVotes: totalVotes,
      counts: counts,
      votes: votes,
    );
  }

  Map<String, dynamic> toUiMap() {
    return {
      'question': question,
      'options': options,
      'allowMultiple': allowMultiple,
      if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
      'totalVotes': totalVotes,
      'counts': counts,
      'votes': votes
          .map(
            (v) => {
              'optionIndex': v.optionIndex,
              'userId': v.userId,
            },
          )
          .toList(),
      'hasEnded': hasEnded,
    };
  }

  @override
  List<Object?> get props => [
        question,
        options,
        allowMultiple,
        endsAt,
        totalVotes,
        counts,
        votes,
      ];
}
