import '../entities/live_chat_rules.dart';
import '../repositories/live_session_repository.dart';

class UpdateLiveChatRules {
  const UpdateLiveChatRules(this._repository);

  final LiveSessionRepository _repository;

  Future<LiveChatRules> call({
    required String liveId,
    String? chatMode,
    int? slowModeSeconds,
    List<String>? blockedKeywords,
  }) {
    return _repository.updateChatRules(
      liveId: liveId,
      chatMode: chatMode,
      slowModeSeconds: slowModeSeconds,
      blockedKeywords: blockedKeywords,
    );
  }
}
