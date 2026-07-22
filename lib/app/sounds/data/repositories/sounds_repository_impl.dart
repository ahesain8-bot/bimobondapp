import 'dart:io';

import 'package:bimobondapp/app/sounds/data/datasources/sounds_remote_data_source.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class SoundsRepositoryImpl implements SoundsRepository {
  SoundsRepositoryImpl({required this.remoteDataSource});

  final SoundsRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, SoundsPageEntity>> getSounds({
    int page = 1,
    int limit = 20,
    String? search,
    SoundSort sort = SoundSort.trending,
    String? creatorId,
    String? groupId,
  }) async {
    try {
      final pageResult = await remoteDataSource.getSounds(
        page: page,
        limit: limit,
        search: search,
        sort: sort,
        creatorId: creatorId,
        groupId: groupId,
      );
      return Right(pageResult);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<SoundEntity>>> getTrending({
    int limit = 30,
  }) async {
    try {
      final sounds = await remoteDataSource.getTrending(limit: limit);
      return Right(sounds);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<SoundGroupEntity>>> getGroups() async {
    try {
      final groups = await remoteDataSource.getGroups();
      return Right(groups);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundGroupEntity>> getGroupById(String id) async {
    try {
      final group = await remoteDataSource.getGroupById(id);
      return Right(group);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundsPageEntity>> getMySounds({
    int page = 1,
    int limit = 20,
    String? search,
    SoundSort sort = SoundSort.recent,
  }) async {
    try {
      final pageResult = await remoteDataSource.getMySounds(
        page: page,
        limit: limit,
        search: search,
        sort: sort,
      );
      return Right(pageResult);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundDetailEntity>> getSoundById(String id) async {
    try {
      final detail = await remoteDataSource.getSoundById(id);
      return Right(detail);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundsSegmentsPageEntity>> getSoundSegments({
    required String soundId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final pageResult = await remoteDataSource.getSoundSegments(
        soundId: soundId,
        page: page,
        limit: limit,
      );
      return Right(pageResult);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundSegmentEntity>> createSoundSegment({
    required String soundId,
    required int startMs,
    required int endMs,
    String? label,
  }) async {
    try {
      final segment = await remoteDataSource.createSoundSegment(
        soundId: soundId,
        startMs: startMs,
        endMs: endMs,
        label: label,
      );
      return Right(segment);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundSegmentDetailEntity>> getSegmentById(
    String segmentId,
  ) async {
    try {
      final detail = await remoteDataSource.getSegmentById(segmentId);
      return Right(detail);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundEntity>> uploadSound({
    required File audio,
    required int duration,
    String? name,
    File? cover,
  }) async {
    try {
      final sound = await remoteDataSource.uploadSound(
        audio: audio,
        duration: duration,
        name: name,
        cover: cover,
      );
      return Right(sound);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundDetailEntity>> createSoundFromUrl({
    required String audioUrl,
    required int duration,
    String? name,
    String? coverUrl,
    List<double>? waveformPeaks,
  }) async {
    try {
      final detail = await remoteDataSource.createSoundFromUrl(
        audioUrl: audioUrl,
        duration: duration,
        name: name,
        coverUrl: coverUrl,
        waveformPeaks: waveformPeaks,
      );
      return Right(detail);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundDetailEntity>> createFromOriginal({
    required String originalSoundId,
    required String audioUrl,
    required int duration,
    String? name,
    String? coverUrl,
    List<double>? waveformPeaks,
  }) async {
    try {
      final detail = await remoteDataSource.createFromOriginal(
        originalSoundId: originalSoundId,
        audioUrl: audioUrl,
        duration: duration,
        name: name,
        coverUrl: coverUrl,
        waveformPeaks: waveformPeaks,
      );
      return Right(detail);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
