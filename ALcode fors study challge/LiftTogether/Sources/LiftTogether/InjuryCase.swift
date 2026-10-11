import Foundation

/// 伤情。这里不是诊断，而是**搬运禁忌的依据**——
/// 误判伤情会害死人，判错搬运方式只是搬得难受。
enum InjuryCase: String, CaseIterable, Identifiable, Codable {
    case spineSuspected = "疑似脊柱/头颈伤"
    case hipFracture = "髋部骨折"
    case unconscious = "意识不清"
    case bleeding = "大出血"
    case legInjury = "腿部伤"
    case minor = "轻伤，能自己走"

    var id: String { rawValue }

    var handling: Handling {
        switch self {
        case .spineSuspected: .keepAxis
        case .hipFracture: .keepLegStraight
        case .unconscious: .keepAxis
        case .bleeding: .pressureThenMove
        case .legInjury: .dragByClothing
        case .minor: .selfWalk
        }
    }

    enum Handling: String {
        case keepAxis = "保持头颈躯干成一条直线"
        case keepLegStraight = "伤腿伸直，不能背不能拖腿"
        case pressureThenMove = "先持续按压止血，再考虑移动"
        case dragByClothing = "拖衣物移动，不要拉伤肢"
        case selfWalk = "能走就协助步行，别让人躺下"
    }

    /// 绝不能做的事。写进 UI，而不是藏进说明书。
    var contraindications: [String] {
        switch self {
        case .spineSuspected:
            return ["禁止扶人坐起或站起", "禁止扭转躯干", "禁止一人拽胳膊拖行", "上斜坡必须保持水平直线"]
        case .hipFracture:
            return ["禁止背", "禁止让伤腿弯曲", "禁止扶墙走"]
        case .unconscious:
            return ["禁止喂水喂药", "禁止摇晃叫醒", "搬动前后都要保持气道通畅"]
        case .bleeding:
            return ["禁止反复掀开查看伤口", "纱布一旦浸透只能加压不能揭掉"]
        case .legInjury:
            return ["禁止拉伤肢", "禁止让患者负重站立"]
        case .minor:
            return ["不要让他留在原地继续活动"]
        }
    }

    /// 最少需要几个人。乡村现实里这是最关键的一个数：
    /// 人不够就必须先等、必须先清障，而不是硬上。
    var minimumPeople: Int {
        switch self {
        case .spineSuspected: 4
        case .hipFracture: 3
        case .unconscious: 3
        case .bleeding: 2
        case .legInjury: 2
        case .minor: 1
        }
    }

    /// 等救护车的时候先做什么——黄金时间在车来之前。
    var waitingActions: [String] {
        switch self {
        case .spineSuspected, .unconscious:
            return ["让所有人不要动患者", "有人去路口接车并报清门牌或地标", "保持电话畅通，把最近医院名字说一遍"]
        case .hipFracture:
            return ["用衣物垫在伤腿两侧固定", "不要给他喝东西", "清出到门口的通道"]
        case .bleeding:
            return ["找到干净布料直接压住伤口", "记下按压开始的时间"]
        case .legInjury:
            return ["把鞋脱掉，检查脚趾颜色", "清出到门口的通道"]
        case .minor:
            return ["冷水冲洗或冰敷", "有人去路口接车"]
        }
    }

    var isLifeThreatening: Bool {
        switch self {
        case .bleeding, .unconscious, .spineSuspected: true
        case .hipFracture, .legInjury, .minor: false
        }
    }
}
