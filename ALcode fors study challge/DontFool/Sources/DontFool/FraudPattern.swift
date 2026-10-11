import Foundation

/// 诈骗话术的**结构性特征**，不是"关键词黑名单"。
///
/// 关键认知：骗子的话术会一直变（今天说公检法，明天说快递理赔），
/// 但**套路结构不变**——制造恐慌、要求保密、要求转账、要求屏幕共享。
/// 所以我们识别的是"套路组合"，而不是某一句话。
enum FraudScript: String, CaseIterable, Identifiable, Codable {
    case impersonationPolice = "冒充公检法"
    case refundCustomerService = "冒充客服退款"
    case familyEmergency = "冒充亲人出事"
    case investment = "虚假投资理财"
    case healthProduct = "保健品与神医"
    case screenSharing = "要求屏幕共享"

    var id: String { rawValue }

    /// 该套路的触发短语
    var triggers: [String] {
        switch self {
        case .impersonationPolice:
            return ["公安", "police", "涉嫌", "洗钱", "通缉", "案件", "安全账户", "资金清查", "冻结"]
        case .refundCustomerService:
            return ["退款", "理赔", "扣款", "会员扣费", "自动续费", "不处理就", "订单异常", "冒充客服", "支付宝客服", "微信客服"]
        case .familyEmergency:
            return ["我出事了", "我摔了", "急用钱", "先别告诉我", "我是你儿子", "我是你女儿", "手机号换了", "快点转"]
        case .investment:
            return ["内部消息", "稳赚", "高回报", "老师带单", "虚拟货币", "原始股", "导师", "群里", "日收益", "平台返利"]
        case .healthProduct:
            return ["包治百病", "祖传秘方", "专家会诊", "免费领", "疗效显著", "不用吃药", "高人", "偏方"]
        case .screenSharing:
            return ["屏幕共享", "共享屏幕", "屏幕同步", "帮我操作", "你点一下", "我教你操作", "打开视频", "保持通话不要挂"]
        }
    }

    /// 套路的**本质危害**，写给老人看
    var whyDangerous: String {
        switch self {
        case .impersonationPolice: "真公检法办案**永远不会**电话要求把钱转到所谓的安全账户。"
        case .refundCustomerService: "正规退款会原路退回，**不会**让你下载软件、转账或提供验证码。"
        case .familyEmergency: "真着急的家人会直接打电话，而不是用陌生号码加你、并要求保密。"
        case .investment: "承诺保本高收益的，一律是骗局，没有例外。"
        case .healthProduct: "能根治、能替代药物的东西，一定是骗人的。"
        case .screenSharing: "一旦屏幕共享，对方能看到你的验证码、密码和银行卡。"
        }
    }

    /// 该套路的唯一正确动作
    var doThis: String {
        switch self {
        case .impersonationPolice: "挂断，自己拨打 96110 核实，不要回拨对方给的号码。"
        case .refundCustomerService: "挂断，登录官方 App 自行查看，不要点对方发的链接。"
        case .familyEmergency: "挂断，用你原来存的号码打给孩子；孩子答不上来就是假的。"
        case .investment: "不转账、不加群、不下载 App，先问子女或社区。"
        case .healthProduct: "不要买、不要留电话，凡是主动上门的都不买。"
        case .screenSharing: "立刻挂断。凡是要求共享屏幕的，一概不答应。"
        }
    }
}
