import Foundation

/// 确认不是"点一下"就完事。
/// 老人最常见的行为是**看也不看直接划掉**，
/// 所以"已服用"最好由家属用 Face ID / 密码确认一次，而不是老人自己随手点。
struct CaregiverConfirm {
    enum Method {
        case deviceOwnerOnly    // 只能本人面容/指纹确认（家属同住时可帮）
        case withPasscode       // 家属输一次数字口令
        case none
    }

    let method: Method

    func confirmationHint(for slot: DoseSlot) -> String {
        switch method {
        case .deviceOwnerOnly:
            return "请本人或家属用面容 / 指纹确认「\(slot.medication.name)已服」"
        case .withPasscode:
            return "请家属输入口令确认「\(slot.medication.name)已服」"
        case .none:
            return "点一下即可标记已服"
        }
    }

    func allowsSelfConfirm(by person: String, isHouseholdMember: Bool) -> Bool {
        switch method {
        case .none: true
        case .deviceOwnerOnly: true          // 走系统生物识别，不在本层判定
        case .withPasscode: isHouseholdMember || person != "本人"
        }
    }
}
