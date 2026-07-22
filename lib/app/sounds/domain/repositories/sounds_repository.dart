import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class SoundsRepository {
  Future<Either<Failure, SoundsPageEntity>> getSounds({
    int page,
    int limit,
    String? search,
    SoundSort sort,
    String? creatorId,
    String? groupId,
  });

  Future<Either<Failure, List<SoundEntity>>> getTrending({int limit});

  Future<Either<Failure, List<SoundGroupEntity>>> getGroups();

  Future<Either<Failure, SoundGroupEntity>> getGroupById(String id);

  Future<Either<Failure, SoundsPageEntity>> getMySounds({
    int page,
    int limit,
    String? search,
    SoundSort sort,
  });

  Future<Either<Failure, SoundDetailEntity>> getSoundById(String id);

  Future<Either<Failure, SoundsSegmentsPageEntity>> getSoundSegments({
    required String soundId,
    int page,
    int limit,
  });

  Future<Either<Failure, SoundSegmentEntity>> createSoundSegment({
    required String soundId,
    required int startMs,
    required int endMs,
    String? label,
  });

  Future<Either<Failure, SoundSegmentDetailEntity>> getSegmentById(
    String segmentId,
  );

  Future<Either<Failure, SoundEntity>> uploadSound({
    required File audio,
    required int duration,
    String? name,
    File? cover,
  });

  Future<Either<Failure, SoundDetailEntity>> createSoundFromUrl({
    required String audioUrl,
    required int duration,
    String? name,
    String? coverUrl,
    List<double>? waveformPeaks,
  });

  Future<Either<Failure, SoundDetailEntity>> createFromOriginal({
    required String originalSoundId,
    required String audioUrl,
    required int duration,
    String? name,
    String? coverUrl,
    List<double>? waveformPeaks,
  });
}
