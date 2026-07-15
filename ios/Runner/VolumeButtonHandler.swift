import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// Native iOS counterpart to Android's `MainActivity` volume-key interception.
///
/// iOS gives no public API to consume the hardware volume keys the way Android
/// does with `onKeyDown`. Instead we park the system output volume at a mid
/// "anchor" value, observe `AVAudioSession.outputVolume` via KVO, translate any
/// nudge into an "up"/"down" event, then snap the volume back to the anchor so
/// there is headroom in both directions. A hidden `MPVolumeView` in the window
/// suppresses the on-screen volume HUD, so every press becomes a clean count.
///
/// This deliberately relies on `MPVolumeView` slider manipulation, which is not
/// App Store friendly — acceptable here because the app is side-loaded only.
class VolumeButtonHandler: NSObject, FlutterStreamHandler {

  static let channelName = "namjap/volume_buttons"

  private let anchor: Float = 0.5
  private let threshold: Float = 0.005

  private var eventSink: FlutterEventSink?
  private var volumeView: MPVolumeView?
  private var volumeObservation: NSKeyValueObservation?
  private var restoring = false

  // Strong references so the channel and handler outlive `register(with:)`.
  private static var retainedHandler: VolumeButtonHandler?
  private static var retainedChannel: FlutterEventChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let handler = VolumeButtonHandler()
    let channel = FlutterEventChannel(name: channelName, binaryMessenger: messenger)
    channel.setStreamHandler(handler)
    retainedHandler = handler
    retainedChannel = channel
  }

  // MARK: FlutterStreamHandler

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    startObserving()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    eventSink = nil
    return nil
  }

  // MARK: Observation

  private func startObserving() {
    let session = AVAudioSession.sharedInstance()
    do {
      // .ambient keeps the app silent-switch friendly and doesn't interrupt
      // other audio; we only need the session active to read/observe volume.
      try session.setCategory(.ambient, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      NSLog("VolumeButtonHandler: failed to activate audio session: \(error)")
    }

    installHiddenVolumeView()
    resetToAnchor()

    volumeObservation = session.observe(
      \.outputVolume,
      options: [.new]
    ) { [weak self] _, change in
      guard let self = self, let volume = change.newValue else { return }
      self.handleVolume(volume)
    }
  }

  private func stopObserving() {
    volumeObservation?.invalidate()
    volumeObservation = nil

    volumeView?.removeFromSuperview()
    volumeView = nil

    do {
      try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    } catch {
      NSLog("VolumeButtonHandler: failed to deactivate audio session: \(error)")
    }
  }

  private func handleVolume(_ volume: Float) {
    guard !restoring, eventSink != nil else { return }

    let delta = volume - anchor
    if abs(delta) < threshold { return }

    eventSink?(delta > 0 ? "up" : "down")
    resetToAnchor()
  }

  /// Snap the system volume back to the anchor. Guarded by `restoring` so the
  /// KVO callback triggered by our own change is ignored.
  private func resetToAnchor() {
    restoring = true
    setSystemVolume(anchor)
    // Give the platform a beat to emit the programmatic change before we react
    // to real presses again (mirrors the Dart fallback's 60ms window).
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
      self?.restoring = false
    }
  }

  // MARK: MPVolumeView plumbing

  private func installHiddenVolumeView() {
    guard volumeView == nil, let window = Self.keyWindow() else { return }
    // Positioned off-screen so it's invisible but present in the hierarchy,
    // which is what suppresses the system volume HUD.
    let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
    view.isHidden = false
    view.alpha = 0.001
    window.addSubview(view)
    volumeView = view
  }

  private func setSystemVolume(_ value: Float) {
    guard let slider = volumeSlider() else { return }
    DispatchQueue.main.async {
      slider.value = value
      slider.sendActions(for: .valueChanged)
    }
  }

  private func volumeSlider() -> UISlider? {
    volumeView?.subviews.compactMap { $0 as? UISlider }.first
  }

  private static func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow } ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first
  }
}
