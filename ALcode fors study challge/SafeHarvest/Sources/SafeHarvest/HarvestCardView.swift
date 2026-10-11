import SwiftUI

/// 倒计时卡：田间、菜市、批发市场都能一眼看懂"这茬菜什么时候能吃"。
struct HarvestCardView: View {
    let window: HarvestWindow
    let application: Application
    var violations: Int = 0

    @Environment(\.dismiss) private var dismiss
    private let today = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                counterBlock
                detailBlock
                if violations > 0 { violationBanner }
                shareButton
                Spacer()
            }
            .padding(24)
            .background(HarvestTheme.fieldBackground.ignoresSafeArea())
            .navigationTitle("等一等")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private var daysLeft: Int { window.daysRemaining(from: today) }

    private var counterBlock: some View {
        VStack(spacing: 6) {
            if daysLeft > 0 {
                Text("还要等").font(HarvestTheme.section).foregroundStyle(.secondary)
                Text("\(daysLeft)")
                    .font(HarvestTheme.counter)
                    .foregroundStyle(HarvestTheme.color(for: window))
                    .minimumScaleFactor(0.5)
                Text("天").font(HarvestTheme.section).foregroundStyle(.secondary)
            } else {
                Text("可以吃了").font(HarvestTheme.counter).foregroundStyle(.green)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
    }

    private var detailBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("作物", application.crop.emoji + " " + application.crop.name)
            row("药名", application.label.pesticideName.display)
            row("安全间隔期", application.label.safetyIntervalDays.display)
            row("最后施药", window.appliedOn.formatted(.dateTime.year().month().day()))
            row("最早可采收", window.earliestHarvestDate.formatted(.dateTime.year().month().day()))
            if case .text(let times) = application.label.maxApplications {
                row("每季最多", times)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fieldCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(HarvestTheme.body)
    }

    private var violationBanner: some View {
        Label("这批菜里有 \(violations) 次采收早于安全间隔期，存在农残超标风险，不要售卖或食用。",
              systemImage: "exclamationmark.triangle.fill")
            .font(HarvestTheme.body)
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
    }

    private var shareButton: some View {
        ShareLink(item: shareText) {
            Label("发给家人 / 菜贩", systemImage: "square.and.arrow.up")
                .font(HarvestTheme.section)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private var shareText: String {
        var lines = ["【等一等 · 采收提示】\(application.crop.name)"]
        if daysLeft > 0 {
            lines.append("还要等 \(daysLeft) 天，最早可采收日：\(window.earliestHarvestDate.formatted(.dateTime.year().month().day()))")
        } else {
            lines.append("已过安全间隔期，今天可以采收。")
        }
        lines.append("最后施药：\(window.appliedOn.formatted(.dateTime.year().month().day()))")
        lines.append("安全间隔期：\(application.label.safetyIntervalDays.display)")
        if violations > 0 {
            lines.append("⚠️ 本批记录中有 \(violations) 次超期采收，请勿食用或售卖。")
        }
        return lines.joined(separator: "\n")
    }
}
