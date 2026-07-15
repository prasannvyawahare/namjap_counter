import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Mirrors Android's MainActivity: streams hardware volume-key presses to
    // Dart over the `namjap/volume_buttons` EventChannel so they drive the
    // counter. Registered on its own plugin registrar to get a messenger.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VolumeButtonHandler")
    if let messenger = registrar?.messenger() {
      VolumeButtonHandler.register(with: messenger)
    }
  }
}
