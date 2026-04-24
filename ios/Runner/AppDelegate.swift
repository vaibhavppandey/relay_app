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
    guard FileManager.default.fileExists(atPath: url.path) else {
      completion(
        .failure(
          PigeonError(
            code: "save_missing_file",
            message: "Source file not found",
            details: path
          )
        )
      )
      return
    }

    if mime.hasPrefix("image/") || mime.hasPrefix("video/") {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { auth in
        guard auth == .authorized || auth == .limited else {
          completion(
            .failure(
              PigeonError(
                code: "save_permission_denied",
                message: "Photo Library access denied",
                details: nil
              )
            )
          )
          return
        }

        PHPhotoLibrary.shared().performChanges({
          if mime.hasPrefix("video/") {
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
          } else {
            PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
          }
        }) { ok, err in
          if let err {
            completion(
              .failure(
                PigeonError(
                  code: "save_failed",
                  message: err.localizedDescription,
                  details: nil
                )
              )
            )
            return
          }
          completion(.success(ok))
        }
      }
      return
    }

    do {
      let destinationDir = try documentsDirectory()
      let preferredName = name.isEmpty ? url.lastPathComponent : name
      let directDestination = destinationDir.appendingPathComponent(
        preferredName.replacingOccurrences(of: "/", with: "_")
      )
      if url.standardizedFileURL == directDestination.standardizedFileURL {
        completion(.success(true))
        return
      }
      let destinationUrl = uniqueDestinationURL(in: destinationDir, preferredName: preferredName)

      try FileManager.default.copyItem(at: url, to: destinationUrl)
      completion(.success(true))
    } catch {
      completion(
        .failure(
          PigeonError(
            code: "save_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      )
    }
  }

  func shareFile(
    path: String,
    mime: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
      completion(
        .failure(
          PigeonError(
            code: "share_missing_file",
            message: "File not found",
            details: path
          )
        )
      )
      return
    }

    DispatchQueue.main.async {
      let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      guard let root = self.activeRootViewController() else {
        completion(
          .failure(
            PigeonError(
              code: "share_no_root",
              message: "Unable to find active view controller",
              details: nil
            )
          )
        )
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

  private func documentsDirectory() throws -> URL {
    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw PigeonError(
        code: "save_no_documents_dir",
        message: "Could not resolve documents directory",
        details: nil
      )
    }
    return directory
  }

  private func uniqueDestinationURL(in directory: URL, preferredName: String) -> URL {
    let sanitizedRaw = preferredName.replacingOccurrences(of: "/", with: "_")
    let sanitized = sanitizedRaw.isEmpty ? "saved_file" : sanitizedRaw
    let ext = (sanitized as NSString).pathExtension
    let baseName: String
    if ext.isEmpty {
      baseName = sanitized
    } else {
      baseName = (sanitized as NSString).deletingPathExtension
    }

    var candidate = directory.appendingPathComponent(sanitized)
    var suffix = 1
    while FileManager.default.fileExists(atPath: candidate.path) {
      let numbered = ext.isEmpty ? "\(baseName) (\(suffix))" : "\(baseName) (\(suffix)).\(ext)"
      candidate = directory.appendingPathComponent(numbered)
      suffix += 1
    }
    return candidate
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
