import 'package:equatable/equatable.dart';

import '../core/errors/failures.dart';
import 'entities/live_entity.dart';

/// Viewer-side chat rules from `Live.chatMode` / `slowModeSeconds` /
/// `blockedKeywords` and `liveModeration` `chat_rules_updated`.
///
/// Backend remains authoritative. This type only stores the documented
/// contract and derives UI gates from fields already on the live model.
class LiveChatRules extends Equatable {
  const LiveChatRules({
    this.chatMode = everyone,
    this.slowModeSeconds = 0,
    this.blockedKeywords = const [],
  });

  static const everyone = 'EVERYONE';
  static const followers = 'FOLLOWERS';
  static const subscribers = 'SUBSCRIBERS';

  final String chatMode;
  final int slowModeSeconds;
  final List<String> blockedKeywords;

  bool get isEveryone => chatMode == everyone;
  bool get isFollowers => chatMode == followers;
  bool get isSubscribers => chatMode == subscribers;

  static LiveChatRules fromLive(LiveEntity? live) => fromMap(live?.metadata);

  static LiveChatRules fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LiveChatRules();
    final mode = (map['chatMode']?.toString() ?? everyone).toUpperCase();
    final normalized = mode == followers || mode == subscribers
        ? mode
        : everyone;
    final seconds = _asInt(map['slowModeSeconds']) ?? 0;
    return LiveChatRules(
      chatMode: normalized,
      slowModeSeconds: seconds.clamp(0, 60),
      blockedKeywords: _stringList(map['blockedKeywords']),
    );
  }

  /// Applies `chat_rules_updated.chatRules` onto the current rules.
  LiveChatRules mergeChatRules(Map<String, dynamic>? chatRules) {
    if (chatRules == null || chatRules.isEmpty) return this;
    final incoming = LiveChatRules.fromMap(chatRules);
    return LiveChatRules(
      chatMode: chatRules.containsKey('chatMode') ? incoming.chatMode : chatMode,
      slowModeSeconds: chatRules.containsKey('slowModeSeconds')
          ? incoming.slowModeSeconds
          : slowModeSeconds,
      blockedKeywords: chatRules.containsKey('blockedKeywords')
          ? incoming.blockedKeywords
          : blockedKeywords,
    );
  }

  Map<String, dynamic> applyToMetadata(Map<String, dynamic>? existing) {
    final next = Map<String, dynamic>.from(existing ?? const {});
    next['chatMode'] = chatMode;
    next['slowModeSeconds'] = slowModeSeconds;
    next['blockedKeywords'] = List<String>.from(blockedKeywords);
    return next;
  }

  /// Prefer join/live chat-rule keys without dropping the rest of feed metadata.
  static Map<String, dynamic> mergeJoinMetadata({
    Map<String, dynamic>? feed,
    Map<String, dynamic>? join,
  }) {
    final next = Map<String, dynamic>.from(feed ?? const {});
    if (join == null) return next;
    const keys = <String>[
      'chatMode',
      'slowModeSeconds',
      'blockedKeywords',
      'chatMuted',
      'isChatMuted',
      'fanClub',
      'showFanClub',
      'fanClubName',
      'fanClubMemberCount',
      'fanClubEnabled',
    ];
    for (final key in keys) {
      if (join.containsKey(key) && join[key] != null) {
        next[key] = join[key];
      }
    }
    return next;
  }

  /// Case-insensitive substring match, matching the documented contract.
  bool containsBlockedKeyword(String content) {
    final haystack = content.toLowerCase();
    if (haystack.isEmpty) return false;
    for (final raw in blockedKeywords) {
      final word = raw.trim().toLowerCase();
      if (word.isEmpty) continue;
      if (haystack.contains(word)) return true;
    }
    return false;
  }

  /// Reads mute from join/live JSON only when that key already exists.
  static bool? chatMutedFlag(Map<String, dynamic>? map) {
    if (map == null) return null;
    if (map.containsKey('chatMuted')) return map['chatMuted'] == true;
    if (map.containsKey('isChatMuted')) return map['isChatMuted'] == true;
    final restriction = map['restriction'] ?? map['viewerRestriction'];
    if (restriction is Map) {
      final asMap = restriction is Map<String, dynamic>
          ? restriction
          : restriction.map((k, v) => MapEntry(k.toString(), v));
      if (asMap.containsKey('chatMuted')) return asMap['chatMuted'] == true;
      if (asMap.containsKey('isChatMuted')) return asMap['isChatMuted'] == true;
    }
    return null;
  }

  /// Fan-club membership only when the live payload already exposes it.
  static bool? fanClubMemberFrom(Map<String, dynamic>? map) {
    if (map == null) return null;
    if (map.containsKey('isFanClubMember')) {
      return map['isFanClubMember'] == true;
    }
    if (map.containsKey('isMember')) return map['isMember'] == true;
    final fanClub = map['fanClub'];
    if (fanClub is Map && fanClub.containsKey('isMember')) {
      return fanClub['isMember'] == true;
    }
    return null;
  }

  static int remainingSlowModeSeconds(DateTime? until, {DateTime? now}) {
    if (until == null) return 0;
    final seconds = until.difference(now ?? DateTime.now()).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  LiveChatComposerStatus composerStatus({
    required bool chatMuted,
    required bool isHost,
    required bool isFollowing,
    required bool? isFanClubMember,
    DateTime? slowModeUntil,
    DateTime? now,
  }) {
    if (isHost) return const LiveChatComposerStatus.allowed();
    if (chatMuted) {
      return const LiveChatComposerStatus.blocked(LiveChatComposerBlock.muted);
    }
    if (isFollowers && !isFollowing) {
      return const LiveChatComposerStatus.blocked(
        LiveChatComposerBlock.followers,
      );
    }
    // Unknown membership must not be guessed — backend stays authoritative.
    if (isSubscribers && isFanClubMember == false) {
      return const LiveChatComposerStatus.blocked(
        LiveChatComposerBlock.subscribers,
      );
    }
    final remaining = remainingSlowModeSeconds(slowModeUntil, now: now);
    if (remaining > 0) {
      return LiveChatComposerStatus.blocked(
        LiveChatComposerBlock.slowMode,
        slowModeRemainingSeconds: remaining,
      );
    }
    return const LiveChatComposerStatus.allowed();
  }

  /// Structured diff of persisted chat rules. Does not include keyword text.
  static List<LiveChatRuleChange> diff(LiveChatRules previous, LiveChatRules next) {
    final changes = <LiveChatRuleChange>[];
    if (previous.slowModeSeconds != next.slowModeSeconds) {
      if (next.slowModeSeconds <= 0) {
        changes.add(
          const LiveChatRuleChange(LiveChatRuleChangeKind.slowModeDisabled),
        );
      } else if (previous.slowModeSeconds <= 0) {
        changes.add(
          LiveChatRuleChange(
            LiveChatRuleChangeKind.slowModeEnabled,
            seconds: next.slowModeSeconds,
          ),
        );
      } else {
        changes.add(
          LiveChatRuleChange(
            LiveChatRuleChangeKind.slowModeChanged,
            seconds: next.slowModeSeconds,
          ),
        );
      }
    }
    if (previous.chatMode != next.chatMode) {
      switch (next.chatMode) {
        case followers:
          changes.add(
            const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers),
          );
        case subscribers:
          changes.add(
            const LiveChatRuleChange(LiveChatRuleChangeKind.chatSubscribers),
          );
        default:
          changes.add(
            const LiveChatRuleChange(LiveChatRuleChangeKind.chatEveryone),
          );
      }
    }
    if (!_keywordsEqual(previous.blockedKeywords, next.blockedKeywords)) {
      changes.add(
        const LiveChatRuleChange(LiveChatRuleChangeKind.blockedKeywords),
      );
    }
    return changes;
  }

  static bool _keywordsEqual(List<String> a, List<String> b) {
    final left = a
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final right = b
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    return left.length == right.length && left.containsAll(right);
  }

  @override
  List<Object?> get props => [chatMode, slowModeSeconds, blockedKeywords];

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
  }
}

enum LiveChatComposerBlock { none, muted, followers, subscribers, slowMode }

class LiveChatComposerStatus extends Equatable {
  const LiveChatComposerStatus.allowed()
    : canSend = true,
      block = LiveChatComposerBlock.none,
      slowModeRemainingSeconds = 0;

  const LiveChatComposerStatus.blocked(
    this.block, {
    this.slowModeRemainingSeconds = 0,
  }) : canSend = false;

  final bool canSend;
  final LiveChatComposerBlock block;
  final int slowModeRemainingSeconds;

  @override
  List<Object?> get props => [canSend, block, slowModeRemainingSeconds];
}

enum LiveChatNoticeKind {
  muted,
  unmuted,
  mutedReason,
  rulesUpdated,
  followToComment,
  subscribeToComment,
  blockedKeyword,
  slowMode,
  sendFailed,
  deleteFailed,
}

enum LiveChatRuleChangeKind {
  slowModeEnabled,
  slowModeChanged,
  slowModeDisabled,
  chatEveryone,
  chatFollowers,
  chatSubscribers,
  blockedKeywords,
}

class LiveChatRuleChange extends Equatable {
  const LiveChatRuleChange(this.kind, {this.seconds});

  final LiveChatRuleChangeKind kind;
  final int? seconds;

  @override
  List<Object?> get props => [kind, seconds];
}

class LiveChatNotice extends Equatable {
  const LiveChatNotice(
    this.kind, {
    this.serverMessage,
    this.seconds,
    this.reason,
    this.ruleChanges = const [],
  });

  final LiveChatNoticeKind kind;
  final String? serverMessage;
  final int? seconds;
  final String? reason;
  final List<LiveChatRuleChange> ruleChanges;

  @override
  List<Object?> get props => [kind, serverMessage, seconds, reason, ruleChanges];
}

enum LiveCommentSendFailureKind {
  muted,
  slowMode,
  followers,
  subscribers,
  blockedKeyword,
  generic,
}

class LiveCommentSendFailure {
  const LiveCommentSendFailure({required this.kind, this.serverMessage});

  final LiveCommentSendFailureKind kind;
  final String? serverMessage;

  factory LiveCommentSendFailure.parse(Failure failure) {
    final rawCode = failure.code?.trim() ?? '';
    final detailsCode = _detailsCode(failure.details);
    final code = (detailsCode ?? rawCode).toLowerCase();
    final cleaned = sanitizeServerMessage(failure.message);
    final lower = [
      if (cleaned != null) cleaned.toLowerCase(),
      failure.message.toLowerCase(),
      code,
    ].join(' ');

    LiveCommentSendFailureKind? fromCode(String value) {
      switch (value.replaceAll('-', '_')) {
        case 'chat_muted':
        case 'muted':
        case 'mute':
          return LiveCommentSendFailureKind.muted;
        case 'slow_mode':
        case 'slowmode':
          return LiveCommentSendFailureKind.slowMode;
        case 'followers':
        case 'followers_only':
        case 'chat_followers':
          return LiveCommentSendFailureKind.followers;
        case 'subscribers':
        case 'subscribers_only':
        case 'fan_club':
        case 'fanclub':
          return LiveCommentSendFailureKind.subscribers;
        case 'blocked_keyword':
        case 'blocked_keywords':
        case 'prohibited_word':
          return LiveCommentSendFailureKind.blockedKeyword;
        default:
          return null;
      }
    }

    final coded = fromCode(code);
    if (coded != null) {
      return LiveCommentSendFailure(kind: coded, serverMessage: cleaned);
    }

    if (_containsAny(lower, const [
      'blocked keyword',
      'blocked word',
      'prohibited',
      'blacklisted',
    ])) {
      return LiveCommentSendFailure(
        kind: LiveCommentSendFailureKind.blockedKeyword,
        serverMessage: cleaned,
      );
    }
    if (_containsAny(lower, const ['slow mode', 'slowmode', 'slow_mode'])) {
      return LiveCommentSendFailure(
        kind: LiveCommentSendFailureKind.slowMode,
        serverMessage: cleaned,
      );
    }
    if (_containsAny(lower, const [
      'fan club',
      'fan-club',
      'fanclub',
      'subscriber',
    ])) {
      return LiveCommentSendFailure(
        kind: LiveCommentSendFailureKind.subscribers,
        serverMessage: cleaned,
      );
    }
    if (_containsAny(lower, const [
          'followers only',
          'followers-only',
          'follow the host',
          'must follow',
          'not following',
        ]) ||
        (lower.contains('follower') && !lower.contains('unfollow'))) {
      return LiveCommentSendFailure(
        kind: LiveCommentSendFailureKind.followers,
        serverMessage: cleaned,
      );
    }
    if (lower.contains('unmute')) {
      return LiveCommentSendFailure(
        kind: LiveCommentSendFailureKind.generic,
        serverMessage: cleaned,
      );
    }
    if (_containsAny(lower, const ['muted', 'mute'])) {
      return LiveCommentSendFailure(
        kind: LiveCommentSendFailureKind.muted,
        serverMessage: cleaned,
      );
    }
    return LiveCommentSendFailure(
      kind: LiveCommentSendFailureKind.generic,
      serverMessage: cleaned,
    );
  }

  LiveChatNotice toNotice({int? slowModeSeconds}) {
    switch (kind) {
      case LiveCommentSendFailureKind.muted:
        return LiveChatNotice(
          LiveChatNoticeKind.muted,
          serverMessage: serverMessage,
        );
      case LiveCommentSendFailureKind.slowMode:
        return LiveChatNotice(
          LiveChatNoticeKind.slowMode,
          serverMessage: serverMessage,
          seconds: slowModeSeconds,
        );
      case LiveCommentSendFailureKind.followers:
        return const LiveChatNotice(LiveChatNoticeKind.followToComment);
      case LiveCommentSendFailureKind.subscribers:
        return const LiveChatNotice(LiveChatNoticeKind.subscribeToComment);
      case LiveCommentSendFailureKind.blockedKeyword:
        return LiveChatNotice(
          LiveChatNoticeKind.blockedKeyword,
          serverMessage: serverMessage,
        );
      case LiveCommentSendFailureKind.generic:
        return LiveChatNotice(
          LiveChatNoticeKind.sendFailed,
          serverMessage: serverMessage,
        );
    }
  }

  /// Strips client wrapping without inventing a substitute error code.
  static String? sanitizeServerMessage(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    const prefixes = <String>[
      'Failed to send comment: ',
      'Failed to delete comment: ',
      'UnauthorizedException: ',
      'BadRequestException: ',
      'NotFoundException: ',
      'ApiException: ',
      'Exception: ',
    ];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }
    text = text.replaceAll(RegExp(r'\s*\(statusCode:\s*\d+\)\s*$'), '').trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('http ') ||
        lower == 'null' ||
        lower.startsWith('instance of')) {
      return null;
    }
    return text;
  }

  static String? _detailsCode(dynamic details) {
    if (details is! Map) return null;
    final code = details['code'] ?? details['error'] ?? details['errorCode'];
    if (code == null) return null;
    final text = code.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

class LiveChatModerationAccess {
  const LiveChatModerationAccess._();

  static bool canShowMenu({
    required String? currentUserId,
    required String? hostId,
    required Iterable<String> moderatorIds,
    required String commentUserId,
    Map<String, dynamic>? metadata,
  }) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    final isHostOrMod =
        currentUserId == hostId || moderatorIds.contains(currentUserId);
    if (!isHostOrMod) return false;
    if (commentUserId == currentUserId) return false;
    final type = metadata?['type']?.toString();
    if (type == 'join' || type == 'gift') return false;
    return true;
  }
}
