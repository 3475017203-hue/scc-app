import SwiftUI

/// 身体的"位置词典"。老人往往说不清术语，但**总能指出哪里疼**——
/// 这一层把"指哪儿"翻译成医生听得懂的解剖学位置 + 常见病因。
enum BodyRegion: String, CaseIterable, Identifiable, Codable {
    case head, eye, ear, throat
    case chest, upperAbdomen, lowerAbdomen, back
    case arm, joint, leg, skin

    var id: String { rawValue }

    enum Side: String, Codable, CaseIterable {
        case none = "整体", left = "左侧", right = "右侧", both = "双侧"
    }

    var label: String {
        switch self {
        case .head: "头 / 脑袋"
        case .eye: "眼睛"
        case .ear: "耳朵"
        case .throat: "喉咙 / 脖子"
        case .chest: "胸口"
        case .upperAbdomen: "上腹（胃那块）"
        case .lowerAbdomen: "小腹（肚脐下面）"
        case .back: "腰背"
        case .arm: "手 / 胳膊"
        case .joint: "关节 / 骨头"
        case .leg: "腿 / 脚"
        case .skin: "全身皮肤"
        }
    }

    /// 写给医生的位置说明
    var doctorText: String {
        switch self {
        case .head: "头部"
        case .eye: "眼部"
        case .ear: "耳部"
        case .throat: "颈部 / 咽喉"
        case .chest: "胸部（心肺区）"
        case .upperAbdomen: "上腹部（胃 / 十二指肠区）"
        case .lowerAbdomen: "下腹部（阑尾 / 膀胱区）"
        case .back: "腰背部"
        case .arm: "上肢"
        case .joint: "关节"
        case .leg: "下肢"
        case .skin: "皮肤（全身）"
        }
    }

    /// 提示医生优先考虑的方向 —— 位置本身就是重要的诊断线索。
    var hint: String {
        switch self {
        case .head: "注意是否伴喷射性呕吐、意识改变（急症信号）"
        case .eye: "突发单眼视力丧失属眼科急症"
        case .ear: "注意是否伴眩晕、听力骤降"
        case .throat: "吞咽困难或声音嘶哑超过 2 周需排查"
        case .chest: "优先排除心源性问题，建议立即心电图"
        case .upperAbdomen: "注意是否为胃溃疡 / 胰腺炎（需查血淀粉酶）"
        case .lowerAbdomen: "右下腹固定压痛警惕阑尾炎，需查血常规"
        case .back: "注意是否伴下肢放射痛（腰椎间盘 / 肾绞痛）"
        case .arm: "单侧无力伴言语不清按卒中流程处理"
        case .joint: "注意红肿热痛与晨僵（痛风 / 类风湿）"
        case .leg: "单侧肿胀压痛警惕深静脉血栓"
        case .skin: "皮疹 + 呼吸困难警惕过敏性休克"
        }
    }

    var urgencyFloor: Urgency {
        switch self {
        case .chest, .arm: .urgent
        case .lowerAbdomen, .leg, .eye: .soon
        default: .routine
        }
    }

    var icon: String {
        switch self {
        case .head: "person.crop.circle.fill"
        case .eye: "eye.fill"
        case .ear: "ear.fill"
        case .throat: "mouth.fill"
        case .chest: "lungs.fill"
        case .upperAbdomen: "fork.knife"
        case .lowerAbdomen: "arrow.down.circle.fill"
        case .back: "arrow.uturn.backward.circle.fill"
        case .arm: "hand.raised.fill"
        case .joint: "bone.fill"
        case .leg: "figure.walk"
        case .skin: "hand.point.up.left.fill"
        }
    }
}

struct BodySpot: Identifiable, Codable, Hashable {
    let id: UUID
    let region: BodyRegion
    let side: BodyRegion.Side

    init(id: UUID = UUID(), region: BodyRegion, side: BodyRegion.Side) {
        self.id = id
        self.region = region
        self.side = side
    }

    var display: String {
        side == .none ? region.label : "\(side.rawValue)\(region.label)"
    }
}
