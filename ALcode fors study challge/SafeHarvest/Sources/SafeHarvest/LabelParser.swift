import Foundation

/// 标签解析：从 OCR 出来的**一堆文字**里，抽我们真正需要的四个字段。
///
/// 核心原则：抽不到就是抽不到。宁可让用户手填，也不给一个"看起来很合理"的错数字——
/// 间隔期猜错一天，就是一批菜能不能吃的问题。
struct LabelParser {
    /// 不同厂家叫法不一样，全部列出来
    static let intervalKeys = ["安全间隔期", "安全间隔", "采收间隔期", "采收安全间隔期", "间隔期"]
    static let maxUseKeys = ["每季最大使用次数", "每季最多使用次数", "最多使用次数", "最大使用次数"]

    func parse(_ raw: String) -> LabelReading {
        let text = raw.replacingOccurrences(of: "：", with: ":")
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "\u{3000}", with: "")

        var reading = LabelReading()
        reading.rawText = raw
        reading.safetyIntervalDays = firstDays(in: text, afterAnyOf: Self.intervalKeys)
        reading.maxApplications = firstCount(in: text, afterAnyOf: Self.maxUseKeys)
        reading.pesticideName = name(in: text)
        reading.activeIngredient = activeIngredient(in: text)
        return reading
    }

    // MARK: - 字段抽取

    private func firstDays(in text: String, afterAnyOf keys: [String]) -> LabelField {
        for key in keys {
            guard let range = text.range(of: key) else { continue }
            let tail = text[range.upperBound...].prefix(12)
            if let value = firstInteger(in: String(tail)) {
                return .days(value)
            }
        }
        return .unknown
    }

    private func firstCount(in text: String, afterAnyOf keys: [String]) -> LabelField {
        for key in keys {
            guard let range = text.range(of: key) else { continue }
            let tail = text[range.upperBound...].prefix(12)
            if let value = firstInteger(in: String(tail)) {
                return .text("\(value) 次")
            }
        }
        return .unknown
    }

    private func firstInteger(in s: String) -> Int? {
        var digits = ""
        for ch in s {
            if ch.isNumber {
                digits.append(ch)
            } else if digits.isEmpty {
                continue     // 跳过冒号、空格等前导噪声
            } else {
                break
            }
            if digits.count >= 3 { break }
        }
        guard !digits.isEmpty, let value = Int(digits), value >= 0, value <= 365 else { return nil }
        return value
    }

    /// 药名通常在包装最上方、字号最大，OCR 里常带括号或含量。
    private func name(in text: String) -> LabelField {
        for key in ["农药名称", "产品名称", "名称"] {
            guard let range = text.range(of: key) else { continue }
            let tail = String(text[range.upperBound...].prefix(16))
            let cleaned = tail
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "()（）"))
            if !cleaned.isEmpty { return .text(String(cleaned.prefix(12))) }
        }
        // 退而求其次：含有"%"的短行通常是有效成分名
        return .unknown
    }

    private func activeIngredient(in text: String) -> LabelField {
        for key in ["有效成分", "成份", "含量"] {
            guard let range = text.range(of: key) else { continue }
            let tail = String(text[range.upperBound...].prefix(16))
            let cleaned = tail.replacingOccurrences(of: ":", with: "")
            if !cleaned.isEmpty, cleaned.contains("%") { return .text(String(cleaned.prefix(12))) }
        }
        return .unknown
    }
}

/// OCR 抽象：真机用 Vision，Playgrounds 用预置文本，评委照样能跑通全流程。
protocol LabelScanning: AnyObject {
    func scan(completion: @escaping (Result<String, Error>) -> Void)
}

final class ScriptedLabelScanner: LabelScanning {
    private var queue: [String] = []
    private let delay: Double

    init(delay: Double = 1.0) { self.delay = delay }

    func enqueue(_ samples: [String]) { queue.append(contentsOf: samples) }

    func scan(completion: @escaping (Result<String, Error>) -> Void) {
        let next = queue.isEmpty ? "" : queue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if next.isEmpty {
                completion(.failure(LabelScanError.noSample))
            } else {
                completion(.success(next))
            }
        }
    }
}

enum LabelScanError: LocalizedError {
    case noSample, cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .noSample: "没有可用的扫描样本，请改用手动输入"
        case .cameraUnavailable: "当前环境不支持相机，请手动输入标签内容"
        }
    }
}
