import SwiftUI

/// 把「两个信源对不上」这件事，用人话讲清楚。
/// 这不是错误弹窗，而是一个**停下来核对**的界面——
/// 安全产品的价值往往体现在它拒绝自动下结论的那一瞬间。
struct DictionaryCrossCheckView: View {
    let result: PesticideDictionary.LookupResult
    let crop: Crop
    var onUseLabel: () -> Void
    var onUseDictionary: () -> Void
    var onManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch result {
            case .matched(let entry, let days):
                ok(entry: entry, days: days)
            case .mismatch(let labelDays, let dictDays):
                mismatch(labelDays: labelDays, dictDays: dictDays)
            case .notFound:
                neutral("词典里没有这个成分。以药瓶标签为准——这很正常，请核对标签上的数字。")
            case .noIntervalForCrop:
                neutral("词典收录了它，但没有\(crop.name)这一类的间隔期。以标签为准。")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.green.opacity(0.2), lineWidth: 1))
    }

    private func ok(entry: PesticideDictionary.Entry, days: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("标签与词典一致：\(days) 天", systemImage: "checkmark.seal.fill")
                .font(HarvestTheme.section).foregroundStyle(.green)
            Text("有效成分 \(entry.activeIngredient)，\(crop.name)安全间隔期 \(days) 天。两个独立来源核对通过。")
                .font(HarvestTheme.body)
            Text(entry.source.line)
                .font(.footnote).foregroundStyle(entry.source.verified ? .secondary : .orange)
        }
    }

    private func mismatch(labelDays: Int, dictDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("两个来源对不上，先别急", systemImage: "exclamationmark.triangle.fill")
                .font(HarvestTheme.section).foregroundStyle(.orange)
            Text("标签上读到 \(labelDays) 天，离线词典记的是 \(dictDays) 天。可能是标签被 OCR 读错了——7 看成 1 是最常见的一种。")
                .font(HarvestTheme.body)
            HStack {
                Button("以标签为准（\(labelDays) 天）", action: onUseLabel).buttonStyle(.bordered)
                Button("以词典为准（\(dictDays) 天）", action: onUseDictionary)
                    .buttonStyle(.borderedProminent).tint(.orange)
            }
            Button("我自己填", action: onManual).buttonStyle(.bordered)
            Text("这几天先别采，也不要按较短的日期行动。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func neutral(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("需要你核对", systemImage: "magnifyingglass.circle.fill")
                .font(HarvestTheme.section).foregroundStyle(.orange)
            Text(text).font(HarvestTheme.body)
        }
    }
}
