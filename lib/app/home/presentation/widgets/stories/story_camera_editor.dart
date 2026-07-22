import 'dart:io';

import 'package:bimobondapp/app/home/presentation/widgets/stories/story_media_preview.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StoryCameraEditor extends StatefulWidget {
  const StoryCameraEditor({
    required this.file,
    required this.type,
    required this.onRetake,
    this.sound,
    this.soundOffset = Duration.zero,
    this.soundWindow = const Duration(seconds: 15),
    super.key,
  });

  final File file;
  final String type;
  final VoidCallback onRetake;
  final SoundEntity? sound;
  final Duration soundOffset;
  final Duration soundWindow;

  @override
  State<StoryCameraEditor> createState() => _StoryCameraEditorState();
}

class _StoryCameraEditorState extends State<StoryCameraEditor> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    FocusScope.of(context).unfocus();
    final caption = _captionController.text.trim();
    final sound = widget.sound;
    String? soundSegmentId;
    String? soundId;
    int? startMs;
    int? endMs;

    if (sound != null && sound.id.isNotEmpty) {
      final trackMs = sound.duration > 0 ? sound.duration * 1000 : 0;
      final customClip = trackMs > 0 &&
          (widget.soundOffset > Duration.zero ||
              (widget.soundWindow > Duration.zero &&
                  widget.soundWindow.inMilliseconds < trackMs));

      if (customClip) {
        final clip = SoundEntity.clipRangeMs(
          durationSeconds: sound.duration,
          offset: widget.soundOffset,
          window: widget.soundWindow,
        );
        soundId = sound.id;
        startMs = clip.startMs;
        endMs = clip.endMs;
      } else {
        final defaultId = sound.defaultSegment?.id.trim();
        if (defaultId != null && defaultId.isNotEmpty) {
          soundSegmentId = defaultId;
        } else {
          soundId = sound.id;
        }
      }
    }

    if (!mounted) return;
    context.read<PostsBloc>().add(
      CreatePostWithMediaRequestedEvent(
        type: widget.type,
        description: caption.isEmpty ? null : caption,
        privacyStatus: 'PUBLIC',
        allowComments: true,
        allowDuets: false,
        allowStitch: false,
        status: 'PUBLISHED',
        isStory: true,
        files: [widget.file],
        soundId: soundId,
        soundSegmentId: soundSegmentId,
        startMs: startMs,
        endMs: endMs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is PostsFailure) {
          PopupDialogs.showErrorDialog(context, state.message);
        } else if (state is CreatePostSuccess) {
          context.goNamed('home');
        }
      },
      child: BlocBuilder<PostsBloc, PostsState>(
        builder: (context, state) {
          final isPublishing = state is PostsLoading;

          return Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: true,
            body: Stack(
              fit: StackFit.expand,
              children: [
                StoryMediaPreview(file: widget.file, type: widget.type),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                            Color(0x00000000),
                            Color(0xA6000000),
                          ],
                          stops: [0.0, 0.18, 0.72, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p8,
                          vertical: AppSizes.p4,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: isPublishing ? null : widget.onRetake,
                              icon: const Icon(
                                LucideIcons.x,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: isPublishing ? null : _share,
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.p20,
                                  vertical: AppSizes.p10,
                                ),
                              ),
                              child: isPublishing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      l10n.shareStoryButton,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.p24,
                          0,
                          AppSizes.p24,
                          AppSizes.p16,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: TextField(
                            controller: _captionController,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            minLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              hintText: l10n.storyCaptionHint,
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: AppSizes.p8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
