import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let filePicker = FilePickerBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "reader_app/file_picker",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pick" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.filePicker.pick(result: result)
    }
  }
}

/// 파일 여러 개를 고르게 하고, iOS가 앱 임시 폴더에 만들어 준 복사본의 경로를 돌려준다.
/// 결과에는 단계별 기록(log)을 함께 담아 기기에서만 나는 문제를 추적할 수 있게 한다.
class FilePickerBridge: NSObject, UIDocumentPickerDelegate {
  private var result: FlutterResult?
  private var log: [String] = []

  func pick(result: @escaping FlutterResult) {
    // 이전 요청이 끝나지 않은 채 남아 있으면 빈 결과로 정리한다.
    finish(paths: [], note: "superseded")
    log = ["pick"]

    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    guard var presenter = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      result(["paths": [String](), "log": ["pick", "no window"]])
      return
    }
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    self.result = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = true
    picker.shouldShowFileExtensions = true
    presenter.present(picker, animated: true) { [weak self] in
      self?.log.append("presented")
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(paths: [], note: "cancelled")
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    finish(paths: urls.map { $0.path }, note: "didPick \(urls.count)")
  }

  private func finish(paths: [String], note: String) {
    guard let result = result else { return }
    self.result = nil
    log.append(note)
    result(["paths": paths, "log": log])
  }
}
