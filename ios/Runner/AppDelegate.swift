import Flutter
import UIKit
import UserNotifications
import AVFoundation

class SilentAudioPlayer: NSObject, AVAudioPlayerDelegate {
  static let shared = SilentAudioPlayer()
  private var player: AVAudioPlayer?
  private var isRunning = false
  private var observersConfigured = false

  override init() {
    super.init()
    setupObservers()
  }

  private func setupObservers() {
    guard !observersConfigured else { return }
    observersConfigured = true

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMediaReset),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func handleInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

    if type == .ended {
      print("[iOS KeepAlive] Interruption ended, resuming silent keep-alive...")
      resumePlayback()
    }
  }

  @objc private func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

    switch reason {
    case .oldDeviceUnavailable, .newDeviceAvailable, .categoryChange, .routeConfigurationChange:
      resumePlayback()
    default:
      break
    }
  }

  @objc private func handleMediaReset() {
    print("[iOS KeepAlive] Media services were reset. Recreating audio player...")
    stop()
    start()
  }

  @objc private func appDidEnterBackground() {
    resumePlayback()
  }

  @objc private func appDidBecomeActive() {
    resumePlayback()
  }

  private func resumePlayback() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
      try session.setActive(true)
      if player == nil || player?.isPlaying == false {
        player?.prepareToPlay()
        player?.play()
      }
      isRunning = true
    } catch {
      print("[iOS KeepAlive] Failed to resume playback: \(error)")
      // Force recreation
      stop()
      start()
    }
  }

  func start() {
    guard !isRunning || player == nil || player?.isPlaying == false else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
      try session.setActive(true)

      // Generate 1 second of silent 44.1kHz mono WAV data in memory
      let sampleRate: Int32 = 44100
      let numSamples: Int32 = 44100
      let numChannels: Int16 = 1
      let bitsPerSample: Int16 = 16
      let byteRate = sampleRate * Int32(numChannels * bitsPerSample / 8)
      let blockAlign = numChannels * bitsPerSample / 8
      let subchunk2Size = numSamples * Int32(blockAlign)
      let chunkSize = 36 + subchunk2Size

      var header = Data()
      header.append(contentsOf: "RIFF".utf8)
      var cSize = chunkSize.littleEndian
      header.append(Data(bytes: &cSize, count: 4))
      header.append(contentsOf: "WAVEfmt ".utf8)
      var sub1Size = Int32(16).littleEndian
      header.append(Data(bytes: &sub1Size, count: 4))
      var audioFormat = Int16(1).littleEndian
      header.append(Data(bytes: &audioFormat, count: 2))
      var channels = numChannels.littleEndian
      header.append(Data(bytes: &channels, count: 2))
      var sRate = sampleRate.littleEndian
      header.append(Data(bytes: &sRate, count: 4))
      var bRate = byteRate.littleEndian
      header.append(Data(bytes: &bRate, count: 4))
      var bAlign = blockAlign.littleEndian
      header.append(Data(bytes: &bAlign, count: 2))
      var bps = bitsPerSample.littleEndian
      header.append(Data(bytes: &bps, count: 2))
      header.append(contentsOf: "data".utf8)
      var sc2Size = subchunk2Size.littleEndian
      header.append(Data(bytes: &sc2Size, count: 4))

      let silenceData = Data(count: Int(subchunk2Size))
      let fullWavData = header + silenceData

      player = try AVAudioPlayer(data: fullWavData)
      player?.delegate = self
      player?.numberOfLoops = -1
      player?.volume = 0.01
      player?.prepareToPlay()
      player?.play()
      isRunning = true
      print("[iOS KeepAlive] Persistent silent background audio player active.")
    } catch {
      print("[iOS KeepAlive] Failed to start silent audio player: \(error)")
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    player.prepareToPlay()
    player.play()
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    resumePlayback()
  }

  func stop() {
    player?.stop()
    player = nil
    isRunning = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    print("[iOS KeepAlive] Silent background audio player stopped.")
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Automatically start iOS background keep-alive so phone stays running when locked
    SilentAudioPlayer.shared.start()

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let deviceChannel = FlutterMethodChannel(
      name: "com.mediabackup.scanner/device_settings",
      binaryMessenger: controller.binaryMessenger
    )

    deviceChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "startBackgroundKeepAlive":
        SilentAudioPlayer.shared.start()
        result(true)
      case "stopBackgroundKeepAlive":
        SilentAudioPlayer.shared.stop()
        result(true)
      case "isXiaomiDevice", "isStrictOEMDevice", "openXiaomiAutostart", "openAutostartSettings", "requestIgnoreBatteryOptimizations":
        result(false)
      case "isIgnoringBatteryOptimizations":
        result(true)
      case "openAppInfoSettings":
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsUrl) {
          UIApplication.shared.open(settingsUrl, options: [:], completionHandler: { success in
            result(success)
          })
        } else {
          result(false)
        }
      case "shareFile":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
          return
        }
        if FileManager.default.fileExists(atPath: path) {
          let url = URL(fileURLWithPath: path)
          self?.presentShareSheet(items: [url], result: result)
        } else {
          result(FlutterError(code: "FILE_NOT_FOUND", message: "File not found: \(path)", details: nil))
        }
      case "shareMultipleFiles":
        guard let args = call.arguments as? [String: Any],
              let paths = args["paths"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Paths are required", details: nil))
          return
        }
        let urls = paths.filter { FileManager.default.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) }
        if !urls.isEmpty {
          self?.presentShareSheet(items: urls, result: result)
        } else {
          result(FlutterError(code: "FILES_NOT_FOUND", message: "No valid files found to share", details: nil))
        }
      case "trimVideo":
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String,
              let startMs = args["startMs"] as? Double,
              let endMs = args["endMs"] as? Double else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing for video trim", details: nil))
          return
        }
        let muteAudio = (args["muteAudio"] as? Bool) ?? false
        let inputUrl = URL(fileURLWithPath: inputPath)
        let outputUrl = URL(fileURLWithPath: outputPath)

        // Remove existing output file if exists
        try? FileManager.default.removeItem(at: outputUrl)

        let asset = AVAsset(url: inputUrl)
        let exportSession: AVAssetExportSession?
        let timeRange = CMTimeRange(start: CMTime(seconds: startMs / 1000.0, preferredTimescale: 600),
                                    duration: CMTime(seconds: max(0.1, (endMs - startMs) / 1000.0), preferredTimescale: 600))

        if muteAudio {
          let composition = AVMutableComposition()
          if let videoTrack = asset.tracks(withMediaType: .video).first,
             let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            do {
              try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
              compVideoTrack.preferredTransform = videoTrack.preferredTransform
              exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
            } catch {
              result(FlutterError(code: "EXPORT_FAILED", message: "Composition failed: \(error)", details: nil))
              return
            }
          } else {
            result(FlutterError(code: "NO_VIDEO_TRACK", message: "Could not find video track", details: nil))
            return
          }
        } else {
          exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
          exportSession?.timeRange = timeRange
        }

        guard let session = exportSession else {
          result(FlutterError(code: "SESSION_FAILED", message: "Could not create export session", details: nil))
          return
        }

        session.outputURL = outputUrl
        session.outputFileType = .mp4
        session.exportAsynchronously {
          DispatchQueue.main.async {
            switch session.status {
            case .completed:
              result(outputPath)
            case .failed, .cancelled:
              result(FlutterError(code: "EXPORT_ERROR", message: session.error?.localizedDescription ?? "Export failed", details: nil))
            default:
              result(FlutterError(code: "EXPORT_UNKNOWN", message: "Status: \(session.status.rawValue)", details: nil))
            }
          }
        }
      case "scanMediaFile":
        result(true)
      case "extractVideoFrames":
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let startMs = args["startMs"] as? Double,
              let endMs = args["endMs"] as? Double else {
          result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing for frame extraction", details: nil))
          return
        }
        let maxFrames = (args["maxFrames"] as? Int) ?? 12
        let inputUrl = URL(fileURLWithPath: inputPath)
        let asset = AVAsset(url: inputUrl)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 360)

        let duration = max(0.1, (endMs - startMs) / 1000.0)
        let step = duration / Double(maxFrames)

        DispatchQueue.global(qos: .userInitiated).async {
          var frames: [FlutterStandardTypedData] = []
          for i in 0..<maxFrames {
            let t = (startMs / 1000.0) + (Double(i) * step)
            let cmTime = CMTime(seconds: t, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
              let uiImage = UIImage(cgImage: cgImage)
              if let data = uiImage.jpegData(compressionQuality: 0.75) {
                frames.append(FlutterStandardTypedData(bytes: data))
              }
            }
          }
          DispatchQueue.main.async {
            result(frames)
          }
        }
      case "getVideoThumbnail":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path is missing", details: nil))
          return
        }
        let width = (args["width"] as? Double) ?? 360.0
        let height = (args["height"] as? Double) ?? 360.0
        let fileUrl = URL(fileURLWithPath: path)

        DispatchQueue.global(qos: .userInitiated).async {
          let asset = AVAsset(url: fileUrl)
          let generator = AVAssetImageGenerator(asset: asset)
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: width, height: height)

          let cmTime = CMTime(seconds: 0.1, preferredTimescale: 600)
          if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
            let uiImage = UIImage(cgImage: cgImage)
            if let data = uiImage.jpegData(compressionQuality: 0.8) {
              DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: data))
              }
              return
            }
          }
          if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            let uiImage = UIImage(cgImage: cgImage)
            if let data = uiImage.jpegData(compressionQuality: 0.8) {
              DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: data))
              }
              return
            }
          }
          DispatchQueue.main.async {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func presentShareSheet(items: [Any], result: @escaping FlutterResult) {
    guard let rootViewController = window?.rootViewController else {
      result(false)
      return
    }

    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = rootViewController.view
      popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }

    rootViewController.present(activityVC, animated: true) {
      result(true)
    }
  }

  private var bgTask: UIBackgroundTaskIdentifier = .invalid

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    SilentAudioPlayer.shared.start()
    bgTask = application.beginBackgroundTask(withName: "PersistentSyncKeepAlive") { [weak self] in
      guard let self = self else { return }
      if self.bgTask != .invalid {
        application.endBackgroundTask(self.bgTask)
        self.bgTask = .invalid
      }
    }
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    if bgTask != .invalid {
      application.endBackgroundTask(bgTask)
      bgTask = .invalid
    }
    SilentAudioPlayer.shared.start()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
