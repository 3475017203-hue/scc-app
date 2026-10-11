import SwiftUI

struct ContentView: View {
    @StateObject private var store = ApplicationStore()
    private let scheduler: ReminderScheduling = LocalReminderScheduler()
    private let scanner: LabelScanning = ScriptedLabelScanner()
    private let parser = LabelParser()

    @State private var selectedCrop: Crop = Crop.common[0]
    @State private var appliedOn = Date()
    @State private var reading = LabelReading()
    @State private var manualInterval: String = ""
    @State private var scanError: String?
    @State private var result: HarvestWindow?
    @State private var harvestedDates: [Date] = []

    /// 演示样本：真实标签的常见排版，供评委一键跑通
    static let demoLabels = [
        """
        农药名称: 烯酰吗啉
        有效成分: 烯酰吗啉 50%
        安全间隔期: 7天
        每季最大使用次数: 3次
        """,
        """
        产品名称 苦参碱
        有效成分 苦参碱 0.3%
        采收安全间隔期 3 天
        每季最多使用次数 2 次
        """
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HarvestTheme.fieldBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        cropPicker
                        labelSection
                        applyButton
                        if let scanError { banner(scanError, color: .orange) }
                        if let result { resultCard }
                        history
                    }
                    .padding(20)
                }
            }
            .navigationTitle("等一等")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { demoScan() } label: { Image(systemName: "play.circle.fill") }
                        .accessibilityLabel("演示：扫描一张真实标签")
                }
            }
        }
    }

    private var resultCard: some View {
        let application = Application(crop: selectedCrop, label: reading, appliedOn: appliedOn)
        return NavigationLink {
            HarvestCardView(window: result!, application: application,
                            violations: IntervalEngine.violationCount(
                                applications: store.applications(for: selectedCrop),
                                harvestedDates: harvestedDates))
        } label: {
            HStack {
                Image(systemName: "calendar.badge.clock")
                VStack(alignment: .leading) {
                    Text("最早可采收").font(.caption).foregroundStyle(.secondary)
                    Text(result!.earliestHarvestDate.formatted(.dateTime.year().month().day()))
                        .font(HarvestTheme.section)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .font(HarvestTheme.body)
        }
        .fieldCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("这茬菜\n什么时候能吃").font(HarvestTheme.title).foregroundStyle(.green)
            Text("拍一下药瓶标签，自动算出最早可采收日。离线可用，不上传。")
                .font(HarvestTheme.body).foregroundStyle(.secondary)
        }
    }

    private var cropPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("① 种的是什么").font(HarvestTheme.section)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Crop.common) { crop in
                        Button {
                            selectedCrop = crop
                            result = nil
                        } label: {
                            Text("\(crop.emoji) \(crop.name)")
                                .font(HarvestTheme.body)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(selectedCrop.id == crop.id ? Color.green : Color.white.opacity(0.8),
                                            in: Capsule())
                                .foregroundStyle(selectedCrop.id == crop.id ? .white : .primary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fieldCard()
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("② 药瓶标签").font(HarvestTheme.section)
            HStack {
                Button { scan() } label: {
                    Label("扫描标签", systemImage: "camera.viewfinder").font(HarvestTheme.body)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    reading = LabelReading()
                    result = nil
                } label: {
                    Label("重填", systemImage: "arrow.counterclockwise").font(HarvestTheme.body)
                }
                .buttonStyle(.bordered)
            }

            fields

            DictionaryCrossCheckView(
                result: PesticideDictionary.standard.lookup(reading: reading, crop: selectedCrop),
                crop: selectedCrop,
                onUseLabel: { },
                onUseDictionary: { useDictionaryDays() },
                onManual: { }
            )

            if !reading.missing.isEmpty {
                banner("没读到：\(reading.missing.joined(separator: "、"))。请手动输入，千万别猜。", color: .orange)
            }

            if case .unknown = reading.safetyIntervalDays {
                HStack {
                    TextField("安全间隔期（天）", text: $manualInterval)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(HarvestTheme.body)
                    Button("填好了") { applyManual() }.buttonStyle(.bordered)
                }
            }

            DatePicker("③ 最后一次施药日期", selection: $appliedOn, in: ...Date(),
                       displayedComponents: .date)
                .font(HarvestTheme.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fieldCard()
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 6) {
            field("药名", reading.pesticideName.display)
            field("有效成分", reading.activeIngredient.display)
            field("安全间隔期", reading.safetyIntervalDays.display)
            field("每季最大次数", reading.maxApplications.display)
        }
    }

    private func field(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(HarvestTheme.body)
    }

    private var applyButton: some View {
        Button { calculate() } label: {
            Text("算出最早可采收日")
                .font(HarvestTheme.section)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(!reading.isUsable && manualInterval.isEmpty)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这一茬的施药记录").font(HarvestTheme.section)
            let apps = store.applications(for: selectedCrop)
            if apps.isEmpty {
                Text("还没有记录").foregroundStyle(.secondary).font(HarvestTheme.body)
            }
            ForEach(apps) { app in
                HStack {
                    VStack(alignment: .leading) {
                        Text(app.appliedOn.formatted(.dateTime.year().month().day()))
                        Text("间隔 \(app.label.safetyIntervalDays.display)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(app.label.pesticideName.display).foregroundStyle(.secondary)
                }
                .font(HarvestTheme.body)
            }
            Text("提示：同一茬菜打了几遍药，只有最后一次算数。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fieldCard()
    }

    // MARK: - 动作

    private func scan() {
        (scanner as? ScriptedLabelScanner)?.enqueue(Self.demoLabels)
        scanner.scan { outcome in
            switch outcome {
            case .success(let text):
                reading = parser.parse(text)
                scanError = reading.isUsable ? nil : "标签拍糊了，没读到安全间隔期。可以手动填。"
            case .failure(let error):
                scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func demoScan() {
        (scanner as? ScriptedLabelScanner)?.enqueue(Self.demoLabels)
        scan()
    }

    private func applyManual() {
        guard let days = Int(manualInterval), days >= 0 else { return }
        reading.safetyIntervalDays = .days(days)
        scanError = nil
    }

    /// 用户选择「以词典为准」时，才把词典的间隔期写进标签字段
    private func useDictionaryDays() {
        if case .matched(_, let days) = PesticideDictionary.standard.lookup(reading: reading, crop: selectedCrop) {
            reading.safetyIntervalDays = .days(days)
            scanError = nil
        } else if case .mismatch(_, let dictDays) = PesticideDictionary.standard.lookup(reading: reading, crop: selectedCrop) {
            reading.safetyIntervalDays = .days(dictDays)
            scanError = nil
        }
    }

    private func calculate() {
        let application = Application(crop: selectedCrop, label: reading, appliedOn: appliedOn)
        do {
            let window = try IntervalEngine.window(for: application)
            result = window
            store.add(application)
            scheduler.requestAuthorization { granted in
                guard granted else { return }
                scheduler.schedule(
                    title: "\(selectedCrop.name)可以采收了",
                    body: "安全间隔期 \(window.intervalDays) 天已满，今天起可以采收。",
                    at: window.earliestHarvestDate,
                    identifier: application.id.uuidString
                )
            }
        } catch {
            scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func banner(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(HarvestTheme.body)
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
