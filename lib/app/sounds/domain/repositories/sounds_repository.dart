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
  });

  Future<Either<Failure, List<SoundEntity>>> getTrending({int limit});

  Future<Either<Failure, SoundsPageEntity>> getMySounds({
    int page,
    int limit,
  });

  Future<Either<Failure, SoundDetailEntity>> getSoundById(String id);

  Future<Either<Failure, SoundEntity>> uploadSound({
    required File audio,
    required int duration,
    String? name,
  });
}
