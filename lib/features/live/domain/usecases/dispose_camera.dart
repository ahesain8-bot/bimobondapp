import 'package:camera/camera.dart';

import '../repositories/camera_repository.dart';

/// Releases a camera controller and its underlying resources.
class DisposeCamera {
  const DisposeCamera(this._repository);

  final CameraRepository _repository;

  Future<void> call(CameraController controller) {
    return _repository.dispose(controller);
  }
}
