import Foundation

enum DoseSamples {
    /// 一个典型的多病共存老人：降压 + 降糖 + 抗凝 + 镇静
    static let common: [Medication] = [
        Medication(name: "氨氯地平", drugClass: .routine, timesPerDay: 1, hours: [8], dose: "5mg", note: "早上一次"),
        Medication(name: "二甲双胍", drugClass: .glucoseLowering, timesPerDay: 2, hours: [8, 18], dose: "0.5g", withFood: true),
        Medication(name: "华法林", drugClass: .anticoagulant, timesPerDay: 1, hours: [17], dose: "2.5mg", note: "每周查 INR"),
        Medication(name: "唑吡坦", drugClass: .sedative, timesPerDay: 1, hours: [21], dose: "5mg", note: "睡前")
    ]
}
