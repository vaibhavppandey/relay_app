import Flutter
import Photos
import UIKit

final class MediaSaverHandler: NSObject, MediaSaverApi {
  func saveFile(
    path: String,
    name: String,
    mime: String,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    let url = URL(fileURLWithPath: path)

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { auth in
      guard auth == .authorized || auth == .limited else {
        completion(.success(false))
        return
      }

      PHPhotoLibrary.shared().performChanges({
        if mime.hasPrefix("video/") {
          PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        } else {
          PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
        }
      }) { ok, err in
        if err != nil {
          completion(.success(false))
          return
        }
        completion(.success(ok))
      }
    }
  }

  func shareFile(
    path: String,
    mime: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let url = URL(fileURLWithPath: path)
    DispatchQueue.main.async {
      let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      guard let root = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })?.rootViewController else {
        completion(.success(()))
        return
      }

      vc.popoverPresentationController?.sourceView = root.view
      root.present(vc, animated: true)
      completion(.success(()))
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let mediaSaverHandler = MediaSaverHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      MediaSaverApiSetup.setUp(
        binaryMessenger: flutterViewController.binaryMessenger,
        api: mediaSaverHandler
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let reg = engineBridge.pluginRegistry.registrar(forPlugin: "MediaSaverApi")
    MediaSaverApiSetup.setUp(binaryMessenger: reg.messenger(), api: mediaSaverHandler)
  }
}
