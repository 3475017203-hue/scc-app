import Foundation

enum DemoScenarios {
    /// 三段真实感的对话：安全的、疑似危险的、正在被骗的
    static let safeCall: [String] = [
        "王阿姨您好，我是小区物业小李",
        "您上次说阳台的灯不亮了，我下午过去看看？",
        "两点到四点我在家，辛苦你了"
    ]

    static let suspiciousCall: [String] = [
        "喂您好，这里是蚂蚁客服，您的会员要扣费了",
        "您不处理的话会自动从账户扣除",
        "这样吧，我给您开个链接处理一下"
    ]

    static let urgentCall: [String] = [
        "我是XX市公安局的，你儿子涉嫌洗钱，现在要资金清查",
        "这件事你先不要告诉任何人",
        "请你把钱转到安全账户，我先帮你冻结"
    ]
}
