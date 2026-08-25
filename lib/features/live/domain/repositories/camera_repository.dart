import 'package:camera/camera.dart';

/// Contract for camera access used by the presentation layer.
///
/// The UI only knows this interface — the concrete implementation lives
/// in the data layer.
abstract interface class CameraRepository {
  /// Initializes a camera controller for the requested lens direction.
  ///
  /// Returns `null` when no camera could be opened.
  Future<CameraController?> initialize({required bool useFront});

  /// Releases the given controller and its underlying resources.
  Future<void> dispose(CameraController controller);
}
