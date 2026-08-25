import '../entities/live_chat_message.dart';
import '../repositories/live_session_repository.dart';

class SendLiveComment {
  const SendLiveComment(this._repository);

  final LiveSessionRepository _repository;

  Future<LiveChatMessage> call({
    required String liveId,
    required String content,
  }) {
    return _repository.sendComment(liveId: liveId, content: content);
  }
}
