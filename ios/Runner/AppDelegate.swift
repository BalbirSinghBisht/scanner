import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let deviceChannel = FlutterMethodChannel(
      name: "com.mediabackup.scanner/device_settings",
      binaryMessenger: controller.binaryMessenger
    )

    deviceChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
