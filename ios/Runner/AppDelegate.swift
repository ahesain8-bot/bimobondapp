import Flutter
import UIKit
import FirebaseCore
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyC4CoGuenT6EzeS__F-ibMR8o56dB4xVb8")
    FirebaseApp.configure()
    // Registered here, not from the implicit-engine callback: that callback
    // runs before UIKit has built the window from Main.storyboard, and
    // flutter_contacts force-unwraps delegate.window!!.rootViewController!
    // the moment it registers.
    GeneratedPluginRegistrant.register(with: self)

      // Registers the AR camera platform view (Swift-only) so Dart's
      // UiKitView(viewType: ArCameraConstants.viewType) can find it.
      if let registrar = self.registrar(forPlugin: "ArCameraPlatformViewFactory") {
        registrar.register(
          ArCameraPlatformViewFactory(),
          withId: ArCameraConstants.viewType
        )
          
          
          // Channel used by Dart to capture the photo
          let channel = FlutterMethodChannel(
              name: ArCameraConstants.channelName,
              binaryMessenger: registrar.messenger()
            )
          channel.setMethodCallHandler { call, result in
              switch call.method {
              case "takePhoto":
                  ArCameraController.shared.takePhoto { path, errorCode in
                      if let path {
                          result(path)
                      } else {
                          result(FlutterError(code: errorCode ?? "photo_failed", message: nil, details: nil))
                      }
                  }
              case "flipCamera":
                  ArCameraController.shared.flipCamera { isFront in
                      result(isFront)
                  }
              default:
                  result(FlutterMethodNotImplemented)
              }
          }
      }

   
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
