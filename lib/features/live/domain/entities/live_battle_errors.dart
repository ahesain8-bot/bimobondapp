import '../../../../core/network/api_exceptions.dart';

/// PK battle API messages from `lives/mobile-api.md` section 12.
bool isAlreadyInBattleError(Object error) {
  final message = _messageOf(error).toLowerCase();
  final status = error is ApiException ? error.statusCode : null;
  return message.contains('already in a battle') ||
      (status == 400 && message.contains('already') && message.contains('battle'));
}

bool isNoOpponentsError(Object error) {
  return _messageOf(error).toLowerCase().contains('no opponents');
}

bool isEndedLiveStartError(Object error) {
  final message = _messageOf(error).toLowerCase();
  final status = error is ApiException ? error.statusCode : null;
  return status == 400 &&
      (message.contains('ended') ||
          message.contains('not live') ||
          message.contains('cannot start') ||
          message.contains('already ended'));
}

String noOpponentsMessage(Object error) {
  if (isNoOpponentsError(error)) {
    return 'لا يوجد بث مباشر آخر متاح للمنافسة الآن';
  }
  return error is ApiException ? error.message : error.toString();
}

String _messageOf(Object error) =>
    error is ApiException ? error.message : error.toString();
