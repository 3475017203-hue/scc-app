import SwiftUI

struct ContentView: View {
    @StateObject private var vm = SignalViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        sensitivityPanel
                        locationCard
                        urgentCard
                        demoPanel
                        history
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("静听")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { vm.runDemo() } label: { Image(systemName: "play.circle.fill") }
                        .accessibilityLabel("演示四种家庭声音")
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.94, green: 0.95, blue: 0.99),
                                Color(red: 0.88, green: 0.90, blue: 0.97)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("听不见，\n也先知道").font(SignalTheme.title).foregroundStyle(.indigo)
            Text("把敲门、哭声、水开、报警，变成手腕上的节奏。端上识别，不上传。")
                .font(SignalTheme.body).foregroundStyle(.secondary)
        }
    }

    /// 首页只给一条：最紧急的那个。信息越少，越看得见。
    @ViewBuilder
    private var urgentCard: some View {
        if let detection = vm.mostUrgent {
            VStack(alignment: .leading, spacing: 10) {
                Label(detection.event.label, systemImage: detection.event.symbol)
                    .font(SignalTheme.section).foregroundStyle(.white)
                Text(detection.event.meaning).font(SignalTheme.body)
                HapticWaveformView(pattern: HapticComposer.pattern(for: detection.event))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bannerColor(detection.event), in: RoundedRectangle(cornerRadius: 22))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "ear.badge.waveform").font(.system(size: 44))
                Text("还没有动静").font(SignalTheme.section)
                Text("点右上角演示按钮听听看").font(SignalTheme.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private var demoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("四种声音，四种节奏").font(SignalTheme.section)
            ForEach(Array(SignalLibrary.demoSamples.enumerated()), id: \.element.name) { index, sample in
                HStack {
                    Image(systemName: sample.event.symbol).foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sample.name).font(SignalTheme.body)
                        Text("震动 \(HapticComposer.pattern(for: sample.event).taps.count) 下 · \(sample.event.severity.label)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { _ = vm.ingest(samples: sample.samples) } label: {
                        Image(systemName: "waveform").font(.title3)
                    }
                    .accessibilityLabel("模拟\(sample.name)")
                }
                if index < SignalLibrary.demoSamples.count - 1 { Divider() }
            }
            if !vm.detections.isEmpty {
                Button("清空记录", action: vm.clear).buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    private var sensitivityPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("要多确定才提醒我").font(SignalTheme.section)
                Spacer()
                if let interference = vm.currentInterference {
                    Label("当前像\(interference.label)", systemImage: "speaker.wave.2.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Picker("灵敏度", selection: $vm.sensitivity) {
                ForEach(Sensitivity.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text("紧急警报（烟雾、漏水）不受严格度影响，永远第一时间提醒。已拦下 \(vm.suppressedCount) 次误报。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var locationCard: some View {
        if let location = vm.location {
            VStack(alignment: .leading, spacing: 8) {
                Text("声音从哪来、多远").font(SignalTheme.section)
                HStack(spacing: 16) {
                    stat("方位", location.bearingText)
                    stat("距离", location.distanceText)
                }
                Text("可信度 \(Int(location.confidence * 100))%")
                    .font(.footnote).foregroundStyle(.secondary)
                if let caveat = location.caveat {
                    Text(caveat).font(.footnote).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(SignalTheme.body).bold()
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日提醒").font(SignalTheme.section)
            if vm.detections.isEmpty {
                Text("暂无").foregroundStyle(.secondary).font(SignalTheme.body)
            }
            ForEach(vm.detections) { detection in
                HStack {
                    Image(systemName: detection.event.symbol).foregroundStyle(.indigo)
                    Text(detection.event.label).font(SignalTheme.body)
                    Spacer()
                    Text(detection.at.formatted(date: .omitted, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    private var disclaimer: some View {
        Text("这不是报警器，也不能替代烟感器与燃气报警器。它只是把声音翻译成节奏，帮你早一点察觉。")
            .font(.footnote).foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func bannerColor(_ event: SoundEvent) -> Color {
        switch event.severity {
        case .low: Color.blue
        case .medium: Color.teal
        case .high: Color.pink
        case .critical: Color.red
        }
    }
}
