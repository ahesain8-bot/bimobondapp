import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera studio needs both camera and microphone for video with sound.
class CameraStudioPermissions {
  CameraStudioPermissions._();

  static Future<bool> ensureCameraAndMicrophone() async {
    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final camera = results[Permission.camera]?.isGranted ?? false;
    final microphone = results[Permission.microphone]?.isGranted ?? false;
    return camera && microphone;
  }

  static Future<bool> ensureMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// CamerAwesome only asks for the mic when [initialCaptureMode] is video.
  static Future<void> requestViaCamerAwesome() async {
    await CamerawesomePlugin.checkAndRequestPermissions(
      false,
      checkCameraPermissions: true,
      checkMicrophonePermissions: true,
    );
  }
}
