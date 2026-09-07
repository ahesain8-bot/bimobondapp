import 'dart:async';

import 'package:bimobondapp/core/utils/cached_video_controller.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/live_replay.dart';
import '../../domain/repositories/live_session_repository.dart';
import '../bloc/live_replay/live_replay_bloc.dart';

/// Replay playback plus the host's clip workflow (features 24 and 25).
///
/// `GET /lives/:id/replay` counts a view, so it runs once when this page opens
/// and again only when the viewer taps Refresh. Nothing preloads it, no timer
/// polls it, and it is never called from `build`.
class LiveReplayPage extends StatefulWidget {
  const LiveReplayPage({
    super.key,
    required this.liveId,
    required this.repository,
    this.isHost = false,
    this.onOpenPost,
  });

  final String liveId;
  final LiveSessionRepository repository;

  /// Host-only controls (publish a replay URL, cut clips, publish a clip).
  final bool isHost;

  /// Navigates to the post created from a clip, when the app has a route.
  final void Function(String postId)? onOpenPost;

  @override
  State<LiveReplayPage> createState() => _LiveReplayPageState();
}

class _LiveReplayPageState extends State<LiveReplayPage> {
  late final LiveReplayBloc _bloc = LiveReplayBloc(
    repository: widget.repository,
    liveId: widget.liveId,
  )..add(const LiveReplayOpened());

  VideoPlayerController? _controller;
  String? _preparedUrl;
  var _preparing = false;
  String? _playerError;

  /// Selected clip bounds, in seconds on the replay timeline.
  double _start = 0;
  double _end = 0;

  /// Stops the preview at [_end] instead of playing to the end of the replay.
  bool _previewing = false;

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _bloc.close();
    super.dispose();
  }

  Future<void> _prepare(String url) async {
    if (_preparing || _preparedUrl == url) return;
    _preparing = true;
    final previous = _controller;
    try {
      final controller = await createCachedVideoController(url);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      previous?.removeListener(_onTick);
      unawaited(previous?.dispose());
      controller.addListener(_onTick);
      setState(() {
        _controller = controller;
        _preparedUrl = url;
        _playerError = null;
        _start = 0;
        _end = controller.value.duration.inMilliseconds / 1000;
      });
    } catch (e) {
      if (mounted) setState(() => _playerError = e.toString());
    } finally {
      _preparing = false;
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !_previewing) return;
    final position = controller.value.position.inMilliseconds / 1000;
    if (position >= _end) {
      _previewing = false;
      unawaited(controller.pause());
    }
  }

  Future<void> _previewSelection() async {
    final controller = _controller;
    if (controller == null || _end <= _start) return;
    _previewing = true;
    await controller.seekTo(Duration(milliseconds: (_start * 1000).round()));
    await controller.play();
  }

  Future<void> _confirmCreateClip() async {
    final l = AppLocalizations.of(context)!;
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.liveClipCreate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.liveClipRange(
                _format(_start),
                _format(_end),
                (_end - _start).round(),
              ),
            ),
            TextField(
              controller: title,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l.liveClipTitle,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.liveClipCreate),
          ),
        ],
      ),
    );
    final chosenTitle = title.text.trim();
    title.dispose();
    if (ok != true) return;
    _bloc.add(
      LiveReplayClipCreated(
        startSeconds: _start,
        endSeconds: _end,
        title: chosenTitle.isEmpty ? null : chosenTitle,
      ),
    );
  }

  Future<void> _confirmPublishClip(LiveClip clip) async {
    final l = AppLocalizations.of(context)!;
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.liveClipPublish),
        content: TextField(
          controller: description,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: l.liveClipDescription,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.liveClipPublish),
          ),
        ],
      ),
    );
    final text = description.text.trim();
    description.dispose();
    if (ok != true) return;
    _bloc.add(
      LiveReplayClipPosted(clip.id, description: text.isEmpty ? null : text),
    );
  }

  Future<void> _publishReplayUrl() async {
    final l = AppLocalizations.of(context)!;
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.liveReplayPublish),
        content: TextField(
          controller: url,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l.liveReplayUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.liveReplayPublish),
          ),
        ],
      ),
    );
    final value = url.text.trim();
    url.dispose();
    if (ok != true || value.isEmpty) return;
    _bloc.add(LiveReplayPublished(value));
  }

  static String _format(double seconds) {
    final total = seconds.round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<LiveReplayBloc, LiveReplayState>(
        listener: (context, state) {
          final replay = state.replay;
          // The player only ever opens a URL the server marked playable.
          if (replay != null && replay.isPlayable) {
            unawaited(_prepare(replay.url!));
          }
          final message = state.message;
          if (message != null && message.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
            _bloc.add(const LiveReplayMessageShown());
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l.liveReplayTitle),
              actions: [
                IconButton(
                  tooltip: l.liveReplayRefresh,
                  onPressed: state.loading
                      ? null
                      : () => _bloc.add(const LiveReplayReloaded()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: state.loading && state.replay == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (state.error != null)
                        _Banner(text: state.error!, icon: Icons.cloud_off),
                      _statusCard(context, state),
                      const SizedBox(height: 12),
                      _player(context, state),
                      if (widget.isHost) ...[
                        const SizedBox(height: 16),
                        _clipEditor(context, state),
                      ],
                      const SizedBox(height: 16),
                      _clipList(context, state),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _statusCard(BuildContext context, LiveReplayState state) {
    final l = AppLocalizations.of(context)!;
    final replay = state.replay;
    final status = replay?.status ?? LiveReplayStatus.none;
    final views = replay?.viewCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l.liveRecordingStatus}: ${status.wireValue}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (views != null) Text(l.liveReplayViews(views)),
            if (replay?.expiresAt != null)
              Text(
                l.liveReplayExpires(
                  replay!.expiresAt!.toLocal().toString().split('.').first,
                ),
              ),
            if (replay != null && replay.isPreparing)
              Text(l.liveReplayPreparing),
            if (replay != null && replay.isGone) Text(l.liveReplayGone),
            if (widget.isHost) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: state.busy ? null : _publishReplayUrl,
                    child: Text(l.liveReplayPublish),
                  ),
                  if (replay != null && replay.isPlayable)
                    OutlinedButton(
                      onPressed: state.busy
                          ? null
                          : () => _bloc.add(const LiveReplayRemoved()),
                      child: Text(l.liveReplayRemove),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _player(BuildContext context, LiveReplayState state) {
    final l = AppLocalizations.of(context)!;
    final replay = state.replay;
    if (replay == null || !replay.isPlayable) {
      return _Banner(
        text: replay != null && replay.isGone
            ? l.liveReplayGone
            : l.liveReplayUnavailable,
        icon: Icons.videocam_off_outlined,
      );
    }
    if (_playerError != null) {
      return _Banner(text: _playerError!, icon: Icons.error_outline);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        VideoProgressIndicator(controller, allowScrubbing: true),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                _previewing = false;
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
                setState(() {});
              },
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
            Text(
              '${_format(controller.value.position.inMilliseconds / 1000)}'
              ' / '
              '${_format(controller.value.duration.inMilliseconds / 1000)}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _clipEditor(BuildContext context, LiveReplayState state) {
    final l = AppLocalizations.of(context)!;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final duration = controller.value.duration.inMilliseconds / 1000;
    if (duration <= 0) return const SizedBox.shrink();
    final end = _end <= _start ? duration : _end;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.liveClipSelect,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            RangeSlider(
              min: 0,
              max: duration,
              values: RangeValues(
                _start.clamp(0, duration),
                end.clamp(0, duration),
              ),
              labels: RangeLabels(_format(_start), _format(end)),
              onChanged: (values) {
                setState(() {
                  _previewing = false;
                  _start = values.start;
                  _end = values.end;
                });
              },
            ),
            Text(
              l.liveClipRange(
                _format(_start),
                _format(end),
                (end - _start).round(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: end > _start ? _previewSelection : null,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: Text(l.liveClipPreview),
                ),
                FilledButton(
                  onPressed: state.busy || end <= _start
                      ? null
                      : _confirmCreateClip,
                  child: Text(l.liveClipCreate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clipList(BuildContext context, LiveReplayState state) {
    final l = AppLocalizations.of(context)!;
    if (state.clips.isEmpty) {
      return _Banner(text: l.liveClipsEmpty, icon: Icons.movie_outlined);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.liveClipsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final clip in state.clips)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              clip.title?.trim().isNotEmpty == true ? clip.title! : clip.id,
            ),
            subtitle: Text(
              [
                clip.status.wireValue,
                if (clip.startSeconds != null && clip.endSeconds != null)
                  l.liveClipRange(
                    _format(clip.startSeconds!.toDouble()),
                    _format(clip.endSeconds!.toDouble()),
                    (clip.endSeconds! - clip.startSeconds!).round(),
                  ),
              ].join(' · '),
            ),
            trailing: clip.isPosted
                ? TextButton(
                    onPressed: clip.postId == null || widget.onOpenPost == null
                        ? null
                        : () => widget.onOpenPost!(clip.postId!),
                    child: Text(l.liveClipOpenPost),
                  )
                : widget.isHost
                ? TextButton(
                    onPressed: state.busy
                        ? null
                        : () => _confirmPublishClip(clip),
                    child: Text(l.liveClipPublish),
                  )
                : null,
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
