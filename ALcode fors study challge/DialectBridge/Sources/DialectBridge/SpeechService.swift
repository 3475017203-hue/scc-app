import Foundation

/// 语音识别抽象。Playgrounds 与真机走同一接口，便于注入 Mock。
protocol SpeechRecognizing: AnyObject {
    var isAvailable: Bool { get }
    var supportedLocaleHint: String { get }
    func requestAuthorization(_ completion: @escaping (Bool) -> Void)
    func transcribe(_ completion: @escaping (Result<String, Error>) -> Void)
}

enum SpeechError: LocalizedError {
    case unavailable
    case denied
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .unavailable: "当前环境不支持设备端语音识别"
        case .denied: "没有麦克风权限，可在「设置 → 隐私 → 麦克风」中开启"
        case .emptyResult: "没有听清，请靠近一点大声再说一遍"
        }
    }
}

/// 演示用：把预设的方言口述逐条"听"出来。
/// 评委在无麦克风权限的 Playground 里也能完整走完整个流程。
final class ScriptedSpeechRecognizer: SpeechRecognizing {
    var isAvailable: Bool { true }
    var supportedLocaleHint: String { "演示模式（脚本转写）" }

    private var queue: [String] = []
    private let delay: Double

    init(delay: Double = 1.1) { self.delay = delay }

    func enqueue(_ utterances: [String]) { queue.append(contentsOf: utterances) }

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) { completion(true) }

    func transcribe(_ completion: @escaping (Result<String, Error>) -> Void) {
        let next = queue.isEmpty ? "" : queue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if next.isEmpty { completion(.failure(SpeechError.emptyResult)) }
            else { completion(.success(next)) }
        }
    }
}
