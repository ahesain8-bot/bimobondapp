import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/core/utils/video_trim_segment.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Native video processing without FFmpeg (MediaCodec / AVFoundation).
class NativeVideoProcessor {
  NativeVideoProcessor._();

  static const _maxVideoFilterSeconds = 60;

  /// Mixes an external [audio] file into [input] (the selected music track).
  ///
  /// Playback starts from [startOffset] inside the audio file and runs for the
  /// video's own duration (TikTok-style "add sound"). When [keepOriginalAudio]
  /// is true the video's recorded audio is preserved and the music is layered
  /// on top; set it false to fully replace the original audio with the music.
  static Future<File?> muxAudioIntoVideo(
    File input, {
    required File audio,
    Duration startOffset = Duration.zero,
    Duration? audioEnd,
    double musicVolume = 1.0,
    bool keepOriginalAudio = true,
  }) async {
    if (kIsWeb) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/music_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(input),
              // 0 = mute original mic/camera audio; music still comes from
              // [audioTracks] below (TikTok "Mute original sound").
              volume: keepOriginalAudio ? 1.0 : 0.0,
            ),
          ],
          outputFormat: VideoOutputFormat.mp4,
          // Keep the audio pipeline on so custom tracks are mixed in even when
          // the video's own track is silenced via [VideoSegment.volume].
          enableAudio: true,
          audioTracks: [
            VideoAudioTrack(
              path: audio.path,
              volume: musicVolume,
              audioStartTime:
                  startOffset <= Duration.zero ? null : startOffset,
              audioEndTime: audioEnd != null && audioEnd > startOffset
                  ? audioEnd
                  : null,
            ),
          ],
        ),
      );

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) return null;
      return output;
    } catch (e, st) {
      debugPrint('Native audio mux failed: $e\n$st');
      return null;
    }
  }

  /// Renders a still [image] into a silent video of [duration] (a single
  /// held frame), then mixes [audio] in from [startOffset]. Used to turn a
  /// captured/gallery photo into a music video (TikTok photo mode).
  static Future<File?> renderImageWithMusic(
    File image, {
    required File audio,
    required Duration duration,
    Duration startOffset = Duration.zero,
    double musicVolume = 1.0,
  }) async {
    if (kIsWeb) return null;

    final silent = await imageToVideo(image, duration: duration);
    if (silent == null) return null;

    final withMusic = await muxAudioIntoVideo(
      silent,
      audio: audio,
      startOffset: startOffset,
      audioEnd: startOffset + duration,
      musicVolume: musicVolume,
      keepOriginalAudio: false,
    );
    // Fall back to the silent clip if muxing failed so we still return a video.
    return withMusic ?? silent;
  }

  /// Encodes a single still [image] into a silent video that holds the frame
  /// for [duration]. No FFmpeg — uses the stop-motion renderer.
  ///
  /// A still photo doesn't need many frames or full sensor resolution, so we
  /// encode at a low frame rate and cap the output to ~1080p. This is what
  /// keeps "photo + music" export fast (the previous 30fps full-res encode was
  /// the main cause of the long processing time).
  static Future<File?> imageToVideo(
    File image, {
    required Duration duration,
  }) async {
    if (kIsWeb) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/img2vid_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final bytes = await image.readAsBytes();
      final resolution = await _cappedResolution(bytes, maxDim: 1080);
      final resultPath = await ProVideoEditor.instance.renderStopMotionToFile(
        outPath,
        StopMotionRenderData(
          frames: [
            StopMotionFrame(
              image: EditorLayerImage.memory(bytes),
              duration: duration,
            ),
          ],
          frameRate: 5,
          resolution: resolution,
          fit: StopMotionFit.contain,
          outputFormat: VideoOutputFormat.mp4,
        ),
      );

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) return null;
      return output;
    } catch (e, st) {
      debugPrint('Native image-to-video failed: $e\n$st');
      return null;
    }
  }

  /// Decodes [bytes] and returns an even-sided [ui.Size] whose longest edge is
  /// at most [maxDim], preserving aspect ratio. Returns null on failure (the
  /// renderer then falls back to the source pixel size).
  static Future<ui.Size?> _cappedResolution(
    Uint8List bytes, {
    required int maxDim,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      if (w <= 0 || h <= 0) return null;

      final longest = w > h ? w : h;
      final scale = longest > maxDim ? maxDim / longest : 1.0;
      var rw = (w * scale).round();
      var rh = (h * scale).round();
      if (rw.isOdd) rw -= 1;
      if (rh.isOdd) rh -= 1;
      if (rw < 2 || rh < 2) return null;
      return ui.Size(rw.toDouble(), rh.toDouble());
    } catch (_) {
      return null;
    }
  }

  static Future<File?> compressVideo(
    File input, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (kIsWeb) return input;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/vid_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await VideoEditorBuilder(videoPath: input.path)
          .compress(resolution: _pickResolution(maxWidth, maxHeight))
          .export(outputPath: outPath);

      if (resultPath == null) return null;

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) return null;

      final originalSize = await input.length();
      final compressedSize = await output.length();
      if (compressedSize >= originalSize) {
        await output.delete();
        return null;
      }
      return output;
    } catch (e, st) {
      debugPrint('Native video compression failed: $e\n$st');
      return null;
    }
  }

  /// Applies a playback-speed change to [input] and returns the new file.
  ///
  /// Uses Media3 Transformer (`SpeedChangeEffect`) which retimes the video with
  /// proper presentation timestamps at full resolution — so the result stays
  /// smooth and sharp, not just "played faster". For [speed] != 1.0 the audio is
  /// stripped ([muteAudio]) to avoid pitch-shifted / chipmunk sound; users add
  /// their own music instead. Removing audio is a lossless passthrough, so the
  /// video is re-encoded only once (by the speed effect).
  static Future<File?> changeSpeed(
    File input, {
    required double speed,
    bool muteAudio = true,
  }) async {
    if (kIsWeb || speed == 1.0) return input;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/speed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      var builder = VideoEditorBuilder(videoPath: input.path);
      if (muteAudio) builder = builder.removeAudio();
      builder = builder.speed(speed: speed);

      final resultPath = await builder.export(outputPath: outPath);
      if (resultPath == null) return null;

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) return null;
      return output;
    } catch (e, st) {
      debugPrint('Native video speed change failed: $e\n$st');
      return null;
    }
  }

  static Future<File?> applyColorMatrix({
    required File input,
    required List<double> matrix,
    Duration? maxDuration,
  }) async {
    if (kIsWeb) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/filter_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(input),
              endTime: maxDuration ??
                  const Duration(seconds: _maxVideoFilterSeconds),
            ),
          ],
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
          colorFilters: [ColorFilter(matrix: matrix)],
        ),
      );

      final output = File(resultPath);
      return await output.exists() ? output : null;
    } catch (e, st) {
      debugPrint('Native color-matrix video bake failed: $e\n$st');
      return null;
    }
  }

  /// Returns the (rotation-corrected) pixel resolution of [input], or null.
  static Future<ui.Size?> videoResolution(File input) async {
    if (kIsWeb) return null;
    try {
      final meta = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(input),
      );
      final r = meta.resolution;
      if (r.width <= 0 || r.height <= 0) return null;
      return r;
    } catch (e, st) {
      debugPrint('Native video metadata failed: $e\n$st');
      return null;
    }
  }

  /// Bakes editor changes onto [input] in a SINGLE render pass, so text,
  /// filters and trimming don't each re-encode the clip:
  ///  - [segments]: kept ranges (trim / split / delete). Empty/null = full clip.
  ///  - [colorMatrix]: a color grade to apply across the output.
  ///  - [overlayPng]: a full-frame transparent PNG holding text/stickers.
  ///
  /// [overlayPng] must match the video's aspect ratio — it's stretched to fill
  /// the frame (WYSIWYG, since the on-screen overlays are placed with the same
  /// BoxFit.cover mapping used to render the PNG).
  static Future<File?> renderVideoEdits({
    required File input,
    List<VideoTrimSegment>? segments,
    List<double>? colorMatrix,
    File? overlayPng,
    Duration? maxDuration,
  }) async {
    if (kIsWeb) return null;
    final hasTrim = segments != null && segments.isNotEmpty;
    if (colorMatrix == null && overlayPng == null && !hasTrim) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/vedit_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final imageLayers = <ImageLayer>[];
      if (overlayPng != null) {
        final overlayBytes = await overlayPng.readAsBytes();
        imageLayers.add(
          ImageLayer(image: EditorLayerImage.memory(overlayBytes)),
        );
      }

      final videoSegments = hasTrim
          ? segments
              .map(
                (r) => VideoSegment(
                  video: EditorVideo.file(input),
                  startTime: r.start,
                  endTime: r.end,
                ),
              )
              .toList()
          : [
              VideoSegment(
                video: EditorVideo.file(input),
                endTime: maxDuration,
              ),
            ];

      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          videoSegments: videoSegments,
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
          colorFilters:
              colorMatrix != null ? [ColorFilter(matrix: colorMatrix)] : const [],
          imageLayers: imageLayers,
        ),
      );

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) return null;
      return output;
    } catch (e, st) {
      debugPrint('Native video edits bake failed: $e\n$st');
      return null;
    }
  }

  static Future<File?> overlayImage({
    required File input,
    required File overlayPng,
  }) async {
    if (kIsWeb) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/effect_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final overlayBytes = await overlayPng.readAsBytes();
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          videoSegments: [VideoSegment(video: EditorVideo.file(input))],
          imageLayers: [
            ImageLayer(
              image: EditorLayerImage.memory(overlayBytes),
            ),
          ],
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
        ),
      );

      final output = File(resultPath);
      return await output.exists() ? output : null;
    } catch (e, st) {
      debugPrint('Native video overlay failed: $e\n$st');
      return null;
    }
  }

  static VideoResolution _pickResolution(int? maxWidth, int? maxHeight) {
    final values = [maxWidth, maxHeight].whereType<int>();
    if (values.isEmpty) return VideoResolution.p720;

    final maxDim = values.reduce((a, b) => a > b ? a : b);
    if (maxDim <= 360) return VideoResolution.p360;
    if (maxDim <= 480) return VideoResolution.p480;
    if (maxDim <= 720) return VideoResolution.p720;
    if (maxDim <= 1080) return VideoResolution.p1080;
    return VideoResolution.p2160;
  }
}
