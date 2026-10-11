import Foundation

#if canImport(Vision)
import Vision
import UIKit

/// 真机端上 OCR：Vision 的中文识别在本机跑，图片不出设备——
/// 农药标签不是敏感数据，但离线仍然让这个 App 在田间、山区也能用。
final class VisionLabelScanner: NSObject, LabelScanning {
    func scan(completion: @escaping (Result<String, Error>) -> Void) {
        #if canImport(UIKit)
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            completion(.failure(LabelScanError.cameraUnavailable))
            return
        }
        // Swift Playgrounds 无相机管线；真机 App 中由相机层回调 image 后调用 recognize(image:completion:)。
        completion(.failure(LabelScanError.cameraUnavailable))
        #else
        completion(.failure(LabelScanError.cameraUnavailable))
        #endif
    }

    /// 真正的识别入口：把相机层拿到的图片传进来。
    func recognize(image: CGImage, completion: @escaping (Result<String, Error>) -> Void) {
        let request = VNRecognizeTextRequest { req, error in
            if let error {
                completion(.failure(error))
                return
            }
            let lines = (req.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            completion(.success(lines.joined(separator: "\n")))
        }
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false   // 标签是术语，纠错反而会改错药名
        request.recognitionLevel = .accurate

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
}
#else
final class VisionLabelScanner: LabelScanning {
    func scan(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(LabelScanError.cameraUnavailable))
    }
}
#endif
