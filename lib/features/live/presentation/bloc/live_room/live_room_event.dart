import 'package:camera/camera.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import '../../../../../core/models/live_battle.dart';

import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';

/// Events handled by [LiveRoomBloc].
sealed class LiveRoomEvent {
  const LiveRoomEvent();
}

/// Requests creating/starting the live-room session and camera / media.
class LiveRoomStarted extends LiveRoomEvent {
  const LiveRoomStarted({this.title, this.initialCamera});

  final String? title;

  /// Reuses the camera already running on the start screen.
  final CameraController? initialCamera;
}

/// Ends the stuck active live (`GET /lives/mine` → `POST …/end`) then retries start.
class LiveRoomRecoverEndAndRestart extends LiveRoomEvent {
  const LiveRoomRecoverEndAndRestart();
}

/// Reconnects to the existing active live (`POST /lives/:id/start`).
class LiveRoomRecoverResumeActive extends LiveRoomEvent {
  const LiveRoomRecoverResumeActive();
}

/// Ends the live session and releases camera resources.
class LiveRoomEndRequested extends LiveRoomEvent {
  const LiveRoomEndRequested();
}

/// The app went to the background; release camera resources.
class LiveRoomAppPaused extends LiveRoomEvent {
  const LiveRoomAppPaused();
}

/// The app returned to the foreground; re-initialize the camera.
class LiveRoomAppResumed extends LiveRoomEvent {
  const LiveRoomAppResumed();
}

/// Bottom-bar chat action tapped.
class LiveRoomChatTapped extends LiveRoomEvent {
  const LiveRoomChatTapped();
}

class LiveRoomChatComposerClosed extends LiveRoomEvent {
  const LiveRoomChatComposerClosed();
}

class LiveRoomChatMessageSubmitted extends LiveRoomEvent {
  const LiveRoomChatMessageSubmitted(this.content);

  final String content;
}

class LiveRoomLikeTapped extends LiveRoomEvent {
  const LiveRoomLikeTapped();
}

class LiveRoomHeartBurstConsumed extends LiveRoomEvent {
  const LiveRoomHeartBurstConsumed();
}

/// The gift banner finished playing; clear it so the next gift can show.
class LiveRoomGiftBannerConsumed extends LiveRoomEvent {
  const LiveRoomGiftBannerConsumed();
}

/// Canonical visual gift received from the shared auction/live socket.
class LiveRoomGiftComboReceived extends LiveRoomEvent {
  const LiveRoomGiftComboReceived(this.payload);

  final GiftComboPayload payload;
}

/// The gift layer presented [payload]; release it so remounting the layer
/// cannot replay an animation the host has already seen.
class LiveRoomGiftComboConsumed extends LiveRoomEvent {
  const LiveRoomGiftComboConsumed(this.payload);

  final GiftComboPayload payload;
}

class LiveRoomTitleSubmitted extends LiveRoomEvent {
  const LiveRoomTitleSubmitted(this.title);

  final String title;
}

class LiveRoomHudEventReceived extends LiveRoomEvent {
  const LiveRoomHudEventReceived(this.event);

  final LiveHudEvent event;
}

class LiveRoomMediaEventReceived extends LiveRoomEvent {
  const LiveRoomMediaEventReceived(this.event);

  final LiveMediaConnectionEvent event;
}

class LiveRoomClearActionMessage extends LiveRoomEvent {
  const LiveRoomClearActionMessage();
}

/// Server ended the live via Socket `liveEnded`.
class LiveRoomRemoteEnded extends LiveRoomEvent {
  const LiveRoomRemoteEnded();
}

/// Bottom-bar share action tapped.
class LiveRoomShareTapped extends LiveRoomEvent {
  const LiveRoomShareTapped();
}

/// Bottom-bar effects action tapped.
class LiveRoomEffectsTapped extends LiveRoomEvent {
  const LiveRoomEffectsTapped();
}

/// Bottom-bar more action tapped (opens the options menu in the UI layer).
class LiveRoomMoreTapped extends LiveRoomEvent {
  const LiveRoomMoreTapped();
}

/// Bottom-bar collab / multi-guest action tapped.
class LiveRoomCollabTapped extends LiveRoomEvent {
  const LiveRoomCollabTapped();
}

/// Bottom-bar viewers action tapped.
class LiveRoomViewersTapped extends LiveRoomEvent {
  const LiveRoomViewersTapped();
}

/// Guest invite chip tapped.
class LiveRoomInviteTapped extends LiveRoomEvent {
  const LiveRoomInviteTapped();
}

/// Hourly ranking chip tapped.
class LiveRoomRankingTapped extends LiveRoomEvent {
  const LiveRoomRankingTapped();
}

/// Visibility of the live effects UI.
enum LiveEffectsPanelMode { hidden, tray, expanded }

/// Opens, closes, or expands the effects UI.
class LiveRoomEffectsPanelModeChanged extends LiveRoomEvent {
  const LiveRoomEffectsPanelModeChanged(this.mode);

  final LiveEffectsPanelMode mode;
}

/// Selects a live effect by catalog id (`none` clears).
class LiveRoomEffectSelected extends LiveRoomEvent {
  const LiveRoomEffectSelected(this.effectId);

  final String effectId;
}

/// Selects an effects category tab in the expanded effects panel.
class LiveRoomEffectsCategorySelected extends LiveRoomEvent {
  const LiveRoomEffectsCategorySelected(this.categoryId);

  final String categoryId;
}

/// Switches between front and back cameras while live.
class LiveRoomFlipCameraRequested extends LiveRoomEvent {
  const LiveRoomFlipCameraRequested();
}

/// Toggles host-preview mirroring.
class LiveRoomMirrorToggled extends LiveRoomEvent {
  const LiveRoomMirrorToggled();
}

/// Toggles microphone mute.
class LiveRoomMicMuteToggled extends LiveRoomEvent {
  const LiveRoomMicMuteToggled();
}

/// Toggles live stabilization mode.
class LiveRoomStabilizationToggled extends LiveRoomEvent {
  const LiveRoomStabilizationToggled();
}

/// Toggles background noise reduction.
class LiveRoomNoiseReductionToggled extends LiveRoomEvent {
  const LiveRoomNoiseReductionToggled();
}

/// Toggles the AI-generated content disclosure tag.
class LiveRoomAiContentToggled extends LiveRoomEvent {
  const LiveRoomAiContentToggled();
}

/// Pauses or resumes the live broadcast (client-only; no backend pause API).
class LiveRoomPauseLiveTapped extends LiveRoomEvent {
  const LiveRoomPauseLiveTapped();
}

/// Navigable / deferred options from the more menu.
enum LiveRoomMenuDestination {
  liveGifts,
  liveHighlights,
  settings,
  comments,
  aboutMe,
  liveTitle,
  events,
  contentDisclosure,
  help,
  reportProblem,
  learnMoreStabilization,
  learnMoreAiContent,
}

/// A menu row that navigates or opens a future sub-flow.
class LiveRoomMenuDestinationRequested extends LiveRoomEvent {
  const LiveRoomMenuDestinationRequested(this.destination);

  final LiveRoomMenuDestination destination;
}

/// External / in-app share destinations from the share sheet.
enum LiveRoomShareChannel {
  whatsApp,
  status,
  copyLink,
  facebook,
  instagramDirect,
  telegram,
  addToStory,
  feedback,
  promote,
  search,
}

/// A recent contact was selected in the share sheet.
class LiveRoomShareContactSelected extends LiveRoomEvent {
  const LiveRoomShareContactSelected({
    required this.contactId,
    required this.displayName,
  });

  final String contactId;
  final String displayName;
}

/// A share-sheet channel or action was requested.
class LiveRoomShareChannelRequested extends LiveRoomEvent {
  const LiveRoomShareChannelRequested(this.channel);

  final LiveRoomShareChannel channel;
}

/// Re-pulls the comment history after the HUD socket comes back, so anything
/// broadcast while it was down is not lost for the rest of the stream.
class LiveRoomCommentsResyncRequested extends LiveRoomEvent {
  const LiveRoomCommentsResyncRequested();
}

/// This user answered a `liveGuestInvite` addressed to them.
class LiveRoomGuestInviteAnswered extends LiveRoomEvent {
  const LiveRoomGuestInviteAnswered({required this.accepted});

  final bool accepted;
}

/// Host or moderator acted on someone waiting for the stage.
class LiveRoomGuestRequestAnswered extends LiveRoomEvent {
  const LiveRoomGuestRequestAnswered({
    required this.userId,
    required this.accepted,
  });

  final String userId;
  final bool accepted;
}

/// Host answers an accepted guest's request to start a PK round.
class LiveRoomCompetitionRequestAnswered extends LiveRoomEvent {
  const LiveRoomCompetitionRequestAnswered({
    required this.commentId,
    required this.accepted,
  });

  final String commentId;
  final bool accepted;
}

/// Guest list changed — refresh pending invite badge.
class LiveRoomGuestsChanged extends LiveRoomEvent {
  const LiveRoomGuestsChanged();
}

/// Applies an HTTP/socket battle snapshot and connects the opponent video.
class LiveRoomBattleChanged extends LiveRoomEvent {
  const LiveRoomBattleChanged(this.battle);

  final LiveBattle? battle;
}

/// Gallery list changed — refresh gallery counts chip.
class LiveRoomGalleryChanged extends LiveRoomEvent {
  const LiveRoomGalleryChanged();
}

/// Settings were saved via `PATCH /lives/:id/settings`.
class LiveRoomSettingsApplied extends LiveRoomEvent {
  const LiveRoomSettingsApplied(this.session);

  final LiveSession session;
}

/// Host moderation actions on a chat message / viewer.
enum LiveRoomModerationAction {
  pin,
  unpin,
  deleteComment,
  muteChat,
  unmuteChat,
  banViewer,
}

class LiveRoomModerationRequested extends LiveRoomEvent {
  const LiveRoomModerationRequested({
    required this.action,
    required this.commentId,
    this.userId,
  });

  final LiveRoomModerationAction action;
  final String commentId;
  final String? userId;
}
