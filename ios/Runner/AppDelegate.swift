import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let folderPicker = FolderPicker()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "reader_app/folder_picker",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pick" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.folderPicker.pick(result: result)
    }
  }
}

/// 폴더를 고르게 한 뒤 앱 임시 폴더로 복사하고 그 경로를 돌려준다.
/// 샌드박스 밖 폴더는 선택 직후 권한을 얻은 동안에만 읽을 수 있어서 여기서 바로 복사한다.
class FolderPicker: NSObject, UIDocumentPickerDelegate {
  private var result: FlutterResult?

  func pick(result: @escaping FlutterResult) {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    guard var presenter = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      result(FlutterError(code: "no_window", message: "화면을 찾을 수 없습니다.", details: nil))
      return
    }
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    self.result = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    result?(nil)
    result = nil
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let result = result else { return }
    self.result = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer {
        if scoped { url.stopAccessingSecurityScopedResource() }
      }
      let fileManager = FileManager.default
      let target = fileManager.temporaryDirectory
        .appendingPathComponent("folder_import")
        .appendingPathComponent(url.lastPathComponent)
      var coordinationError: NSError?
      var copyError: Error?
      NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
        readURL in
        do {
          try? fileManager.removeItem(at: target)
          try fileManager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
          )
          try fileManager.copyItem(at: readURL, to: target)
        } catch {
          copyError = error
        }
      }
      let failure: Error? = coordinationError ?? copyError
      DispatchQueue.main.async {
        if let failure = failure {
          result(
            FlutterError(code: "copy_failed", message: failure.localizedDescription, details: nil))
        } else {
          result(target.path)
        }
      }
    }
  }
}
