import Foundation

/// 充电异常的声音与用电特征。
///
/// 说明：真正可靠的预警需要电流、电压与温度传感器，
/// 手机**拿不到这些数据**。这个作品只做一件事——
/// 把"楼道里正在发生什么"听出来，让人早一点警觉，并在真出事时指挥人怎么走。
struct ChargeSignature {
    let loudnessDB: Double
    /// 冲击密度：锂电池热失控前常见的噼啪声是高密度短冲击
    let crackleRate: Double
    /// 啸叫程度：充电器老化时会出现的高频啸叫
    let whineLevel: Double
    /// 是否有规律的脉冲（充电正常的表现）
    let isRegularPulse: Bool
    /// 是否伴随焦糊味这类不可测但可人工确认的线索
    let reportedSmell: Bool
}

enum ChargeRisk: String {
    case normal = "正常充电"
    case aging = "充电器老化"
    case suspect = "疑似异常，需现场查看"
    case dangerous = "⚠️ 疑似失控前兆，立即撤离并叫火警"
}

/// 判定规则。**宁可多喊一次，也不放过一次**——
/// 这类错误的代价不对称：误报只是白跑一趟，漏报是楼道里的火。
struct ChargeClassifier {
    func risk(_ s: ChargeSignature) -> (ChargeRisk, [String]) {
        var reasons: [String] = []

        if s.crackleRate > 12 {
            reasons.append("每秒约 \(Int(s.crackleRate)) 次噼啪声")
        }
        if s.whineLevel > 0.6 && !s.isRegularPulse {
            reasons.append("充电器啸叫且不规律")
        }
        if s.reportedSmell {
            reasons.append("现场报告有焦糊味")
        }
        if s.loudnessDB < -55 {
            return (.normal, ["环境安静，未检测到充电异常"])
        }

        if s.reportedSmell || s.crackleRate > 20 {
            return (.dangerous, reasons + ["味与噼啪声同时出现，是热失控的典型组合"])
        }
        if s.crackleRate > 12 || s.whineLevel > 0.6 {
            return (.suspect, reasons)
        }
        if s.whineLevel > 0.35 {
            reasons.append("出现轻微啸叫")
            return (.aging, reasons)
        }
        if s.isRegularPulse {
            reasons.append("充电动作规律")
        }
        return (.normal, reasons.isEmpty ? ["未见异常"] : reasons)
    }
}
