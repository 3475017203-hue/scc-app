import Foundation

/// 生成一份**结构化的问询**，让家长去问、去反映时手里有据可依。
///
/// 竞品（溯源小程序、明厨亮灶）只提供查询，
/// 但家长真正需要的不是"查一下"，而是"我该问谁、问什么"。
struct InquiryDraft {
    let school: String
    let batch: BatchTrace
    let today: Date

    var questions: [String] {
        var list: [String] = []
        if !batch.isSafe(on: today) {
            let ready = Calendar.current.date(byAdding: .day, value: batch.safetyIntervalDays, to: batch.lastSprayedOn)
            let readyText = ready?.formatted(.dateTime.month().day()) ?? "?"
            list.append("请问 \(batch.harvestedOn.formatted(.dateTime.month().day())) 采购的这批\(batch.vegetable)，末次施药是 \(batch.lastSprayedOn.formatted(.dateTime.month().day()))，安全间隔期 \(batch.safetyIntervalDays) 天，按规定应在 \(readyText) 之后采收，这批的采收日期是依据什么确定的？")
        }
        list.append("这批\(batch.vegetable)的检测报告是哪一天出的？能否提供？")
        list.append("供应商\(batch.supplier)的资质与承诺达标情况，是否有记录可以查阅？")
        list.append("学校公示屏能否增加公示采收日期，这样家长可以自己核对。")
        return list
    }

    var shareText: String {
        var lines = ["【关于学校午餐用菜的问询】\(school)"]
        lines.append("批次 \(batch.batchId)，\(batch.vegetable)，产地 \(batch.farm)。")
        lines.append("想请教四个问题：")
        for (i, q) in questions.enumerated() {
            lines.append("\(i + 1). \(q)")
        }
        lines.append("谢谢配合。")
        return lines.joined(separator: "\n")
    }
}
