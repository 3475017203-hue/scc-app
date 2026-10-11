import Foundation

#if canImport(Speech)
import Speech

/// 基于 Speech 框架的设备端识别。
/// 关键设计：addsPunctuation 保留口语断句，方言 locale 让"心口疼""哈不动"这类
/// 真实说法被如实转写，再交给 DialectNormalizer 做归一化，而不是让 ASR 直接猜医学词。
final class DialectSpeechRecognizer: NSObject, SpeechRecognizing {
    var isAvailable: Bool { recognizer != nil && recognizer!.supportsOnDeviceRecognition }

    private let recognizer: SFSpeechRecognizer?
    private let localeIdentifier: String

    var supportedLocaleHint: String {
        guard let recognizer else { return "未安装对应语音包" }
        return recognizer.supportsOnDeviceRecognition ? "离线识别 · \(localeIdentifier)" : "该语言需联网识别"
    }

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        super.init()
    }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    /// Swift Playgrounds 没有持续的音频输入管线，这里返回 unavailable；
    /// 真机 App 中应改为：AVAudioEngine 采集 buffer → append(to: request) → resultHandler 回调。
    func transcribe(_ completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(SpeechError.unavailable))
    }
}
#else
final class DialectSpeechRecognizer: SpeechRecognizing {
    var isAvailable: Bool { false }
    var supportedLocaleHint: String { "Speech 框架不可用" }
    init(localeIdentifier: String) {}
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) { completion(false) }
    func transcribe(_ completion: @escaping (Result<String, Error>) -> Void) { completion(.failure(SpeechError.unavailable)) }
}
#endif
