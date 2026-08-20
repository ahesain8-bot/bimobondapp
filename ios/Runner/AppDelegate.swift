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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
