import SwiftUI

enum MealTheme {
    static let title = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct ContentView: View {
    @State private var rawText = MealSamples.boardText
    @State private var trace: BatchTrace?
    @State private var menu = MealSamples.menu(with: nil, compliant: false)
    @State private var missing: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        scanCard
                        traceCard
                        nutritionCard
                        trendCard
                        report
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("来路")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { demoMenu }
            }
        }
    }

    private var demoMenu: some View {
        Menu {
            Button("演示：这批菜超期采收") { load(MealSamples.boardText) }
            Button("演示：这批菜合规") { load(MealSamples.compliantText) }
        } label: {
            Image(systemName: "play.circle.fill")
        }
        .accessibilityLabel("演示两批菜")
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.95, green: 0.98, blue: 0.95), Color(red: 0.89, green: 0.95, blue: 0.89)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("孩子今天这口菜，\n从哪块地来的").font(MealTheme.title).foregroundStyle(.green)
            Text("拍下食堂公示屏或扫溯源码，家长在 30 秒内看到：这批菜今天能不能吃、这顿够不够营养。")
                .font(MealTheme.body).foregroundStyle(.secondary)
        }
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("① 公示屏上的字").font(MealTheme.section)
            TextEditor(text: $rawText)
                .font(.system(size: 16, design: .monospaced))
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
            Button("读一下") { load(rawText) }
                .buttonStyle(.borderedProminent).tint(.green)
            if !missing.isEmpty {
                Text("没读到：\(missing.joined(separator: "、"))。去问食堂，别自己猜。")
                    .font(.footnote).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var traceCard: some View {
        if let trace {
            let ok = trace.isSafe(on: Date())
            VStack(alignment: .leading, spacing: 8) {
                Label(ok ? "这批菜到日子了" : "这批菜超期采收了", systemImage: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(MealTheme.section).foregroundStyle(.white)
                row("蔬菜", trace.vegetable)
                row("产地", trace.farm)
                row("供应商", trace.supplier)
                row("末次施药", trace.lastSprayedOn.formatted(.dateTime.month().day()))
                row("安全间隔期", "\(trace.safetyIntervalDays) 天")
                row("采收日期", trace.harvestedOn.formatted(.dateTime.month().day()))
                if !ok {
                    Text("应至少等到 \(readyDate(trace).formatted(.dateTime.month().day()))，实际 \(trace.harvestedOn.formatted(.dateTime.month().day())) 就采收了。")
                        .font(MealTheme.body)
                    Text("可以要求学校说明，也可以向市场监管部门反映。")
                        .font(.footnote).foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ok ? Color.green : Color.red, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(value).bold()
        }
        .font(MealTheme.body)
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("② 这一餐的营养").font(MealTheme.section)
            Text("今天的菜：\(menu.items.map(\.name).joined(separator: "、"))")
                .font(MealTheme.body)
            let gaps = NutritionTarget.evaluate(menu)
            if gaps.isEmpty {
                Text("蛋白质、钙、维生素 A 都够。").foregroundStyle(.green).font(MealTheme.body)
            }
            ForEach(gaps) { gap in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(gap.title)：\(gap.percent)% · \(gap.status.rawValue)")
                        .font(MealTheme.body)
                        .foregroundStyle(gap.status == .low ? .red : .orange)
                    Text(gap.advice).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text("单看一顿判断不了营养，长期看的是一周。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    private var report: some View {
        ShareLink(item: reportText) {
            Label("把这份「来路」发给家里 / 老师", systemImage: "square.and.arrow.up")
                .font(MealTheme.body)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(trace == nil)
    }

    /// 一周趋势——这个作品真正的价值在这一屏
    @ViewBuilder
    private var trendCard: some View {
        let trend = WeeklyTrend(days: MealSamples.weekRecords())
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("③ 这一周").font(MealTheme.section)
                Spacer()
                Text("已记录 \(trend.coverageDays) 天").font(.footnote).foregroundStyle(.secondary)
            }
            if trend.overHarvestDays > 0 {
                Label("有 \(trend.overHarvestDays) 天出现超期采收", systemImage: "exclamationmark.triangle.fill")
                    .font(MealTheme.body).foregroundStyle(.red)
            }
            let findings = trend.allFindings
            if findings.isEmpty {
                Text("还没有足够的数据下结论（需要至少 4 天）。").font(MealTheme.body).foregroundStyle(.secondary)
            }
            ForEach(findings) { finding in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(finding.title)：平均 \(finding.percent)% · \(finding.days) 天")
                        .font(MealTheme.body).foregroundStyle(finding.ratio < 0.35 ? .red : .orange)
                    Text(finding.advice).font(.footnote).foregroundStyle(.secondary)
                }
            }
            inquiryButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var inquiryButton: some View {
        if let trace {
            let draft = InquiryDraft(school: "阳光镇中心小学", batch: trace, today: Date())
            ShareLink(item: draft.shareText) {
                Label("生成问询，发给老师 / 学校", systemImage: "questionbubble.fill")
                    .font(MealTheme.body)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
    }

    private var disclaimer: some View {
        Text("营养数据是估算，用于发现长期倾向，不能替代体检或医生建议。溯源信息以学校公示与市场监管部门公布为准。")
            .font(.footnote).foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func readyDate(_ trace: BatchTrace) -> Date {
        Calendar.current.date(byAdding: .day, value: trace.safetyIntervalDays, to: trace.lastSprayedOn) ?? trace.lastSprayedOn
    }

    private var reportText: String {
        var lines = ["【一顿饭的来路】"]
        if let trace {
            let ok = trace.isSafe(on: Date())
            lines.append("\(trace.vegetable)（\(trace.farm)）：\(ok ? "到日子了" : "超期采收")。")
            lines.append("末次施药 \(trace.lastSprayedOn.formatted(.dateTime.month().day()))，安全间隔期 \(trace.safetyIntervalDays) 天。")
        }
        let gaps = NutritionTarget.evaluate(menu)
        if gaps.isEmpty {
            lines.append("今天的菜蛋白质、钙、维生素 A 都够。")
        } else {
            lines.append("营养提示：" + gaps.map { "\($0.title) \($0.percent)%" }.joined(separator: "，"))
        }
        return lines.joined(separator: "\n")
    }

    private func load(_ text: String) {
        let parsed = TraceParser().parse(text)
        trace = parsed
        missing = TraceParser().missingFields(in: text)
        menu = MealSamples.menu(with: parsed, compliant: parsed?.isSafe(on: Date()) ?? false)
    }
}
