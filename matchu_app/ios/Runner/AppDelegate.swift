import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let qrImageSaverChannel = "matchu_app/qr_image_saver"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureQrImageSaverChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureQrImageSaverChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: qrImageSaverChannel,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "savePng" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let typedData = args["bytes"] as? FlutterStandardTypedData,
        let fileName = args["fileName"] as? String,
        !typedData.data.isEmpty,
        !fileName.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "Image bytes and fileName are required.",
            details: nil
          )
        )
        return
      }

      self?.savePngToPhotos(data: typedData.data, fileName: fileName, result: result)
    }
  }

  private func savePngToPhotos(data: Data, fileName: String, result: @escaping FlutterResult) {
    requestPhotoAddPermission { isAllowed in
      guard isAllowed else {
        result(
          FlutterError(
            code: "PERMISSION_DENIED",
            message: "Photo library permission was denied.",
            details: nil
          )
        )
        return
      }

      var localIdentifier: String?
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = fileName
        request.addResource(with: .photo, data: data, options: options)
        localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result(localIdentifier ?? "photos://\(fileName)")
          } else {
            result(
              FlutterError(
                code: "SAVE_FAILED",
                message: error?.localizedDescription ?? "Could not save image.",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private func requestPhotoAddPermission(_ completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
      case .authorized, .limited:
        completion(true)
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
          DispatchQueue.main.async {
            completion(status == .authorized || status == .limited)
          }
        }
      case .denied, .restricted:
        completion(false)
      @unknown default:
        completion(false)
      }
    } else {
      switch PHPhotoLibrary.authorizationStatus() {
      case .authorized:
        completion(true)
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization { status in
          DispatchQueue.main.async {
            completion(status == .authorized)
          }
        }
      default:
        completion(false)
      }
    }
  }
}
