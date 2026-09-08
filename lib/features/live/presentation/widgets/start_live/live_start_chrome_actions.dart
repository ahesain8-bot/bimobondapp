/// Native Go LIVE chrome → Flutter.
///
/// [schedule] must open [showLiveSchedulePicker] and must never be aliased
/// to cover / gallery picking.
abstract final class LiveStartChromeMethod {
  static const schedule = 'onLiveStartSchedule';
  static const changeCover = 'onLiveStartChangeCover';
  static const addTopic = 'onLiveStartAddTopic';
}

enum LiveStartChromeAction { schedule, changeCover, addTopic, unknown }

LiveStartChromeAction liveStartChromeActionFor(String method) {
  switch (method) {
    case LiveStartChromeMethod.schedule:
      return LiveStartChromeAction.schedule;
    case LiveStartChromeMethod.changeCover:
      return LiveStartChromeAction.changeCover;
    case LiveStartChromeMethod.addTopic:
      return LiveStartChromeAction.addTopic;
    default:
      return LiveStartChromeAction.unknown;
  }
}

/// Cover picking is not implemented. No chrome action opens the image picker.
bool liveStartChromeOpensImagePicker(LiveStartChromeAction action) => false;
