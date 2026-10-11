import Foundation

/// 三个真实画像的演示脚本 —— 评委在 3 分钟内能看到作品解决三个不同的问题。
enum DemoScenarios {
    struct Scenario: Identifiable {
        let id = UUID()
        let persona: String
        let age: Int
        let dialect: DialectRegion
        let utterance: String
        let line: String
        let spots: [BodySpot]
        let takeaway: String
    }

    static let all: [Scenario] = [
        Scenario(persona: "独居的苏州阿婆", age: 79, dialect: .wu,
                  utterance: "这两天心口闷，压得慌，还气不大来",
                  line: "这两天心口闷，压得慌，还气不大来",
                  spots: [BodySpot(region: .chest, side: .left)],
                  takeaway: "老人只说「压得慌」，卡片把它变成「胸部（心肺区）·左」，分诊直接把它顶到心内科。"),
        Scenario(persona: "刚出院不久的陈伯（粤）", age: 68, dialect: .cantonese,
                  utterance: "呢几日脚肿，鞋都着唔落，着咗药好返，但唔想再住院",
                  line: "呢几日脚肿，鞋都着唔落",
                  spots: [BodySpot(region: .leg, side: .both)],
                  takeaway: "方言 + 焦虑。位置先落地，再把「不想再住院」这句情绪写进卡片，医生才知道该谈什么。"),
        Scenario(persona: "被否定主诉坑过的家属", age: 82, dialect: .sichuan,
                  utterance: "没有脑壳痛，就是胃子痛，肚子痛得很",
                  line: "没有脑壳痛，就是胃子痛，肚子痛得很",
                  spots: [BodySpot(region: .lowerAbdomen, side: .right)],
                  takeaway: "「没有脑壳痛」如果被当成主诉，就会带着老人去做头部检查。这里它被明确标为「患者否认」。")
    ]
}
