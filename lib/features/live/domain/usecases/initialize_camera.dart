import 'package:camera/camera.dart';

import '../repositories/camera_repository.dart';

/// Initializes a camera controller for the requested lens direction.
class InitializeCamera {
  const InitializeCamera(this._repository);

  final CameraRepository _repository;

  Future<CameraController?> call({required bool useFront}) {
    return _repository.initialize(useFront: useFront);
  }
}
