import Flutter
import Photos
import UIKit
import UniformTypeIdentifiers

final class MediaSaverHandler: NSObject, MediaSaverApi, UIDocumentPickerDelegate {
  private var pickCompletion: ((Result<[String], Error>) -> Void)?

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
      guard let root = self.activeRootViewController() else {
        completion(.success(()))
        return
      }

      vc.popoverPresentationController?.sourceView = root.view
      root.present(vc, animated: true)
      completion(.success(()))
    }
  }

  func pickFiles(
    allowMultiple: Bool,
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    DispatchQueue.main.async {
      if self.pickCompletion != nil {
        completion(
          .failure(
            PigeonError(
              code: "picker_busy",
              message: "File picker already open",
              details: nil
            )
          )
        )
        return
      }

      self.pickCompletion = completion
      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(
          forOpeningContentTypes: [UTType.item],
          asCopy: true
        )
      } else {
        picker = UIDocumentPickerViewController(
          documentTypes: ["public.item"],
          in: .import
        )
      }

      picker.delegate = self
      picker.allowsMultipleSelection = allowMultiple

      guard let root = self.activeRootViewController() else {
        self.pickCompletion = nil
        completion(.success([]))
        return
      }

      picker.popoverPresentationController?.sourceView = root.view
      root.present(picker, animated: true)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let completion = pickCompletion
    pickCompletion = nil
    let paths = urls.compactMap { copyToLocalPath($0) }
    completion?(.success(paths))
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let completion = pickCompletion
    pickCompletion = nil
    completion?(.success([]))
  }

  private func copyToLocalPath(_ src: URL) -> String? {
    let access = src.startAccessingSecurityScopedResource()
    defer {
      if access {
        src.stopAccessingSecurityScopedResource()
      }
    }

    guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return nil
    }

    let dst = dir.appendingPathComponent("\(UUID().uuidString)_\(src.lastPathComponent)")
    do {
      if FileManager.default.fileExists(atPath: dst.path) {
        try FileManager.default.removeItem(at: dst)
      }
      try FileManager.default.copyItem(at: src, to: dst)
      return dst.path
    } catch {
      return nil
    }
  }

  private func activeRootViewController() -> UIViewController? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController
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
