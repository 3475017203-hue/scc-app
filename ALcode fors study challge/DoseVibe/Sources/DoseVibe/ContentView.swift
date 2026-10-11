import SwiftUI

enum DoseTheme {
    static let title = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct ContentView: View {
    @StateObject private var vm = DoseViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        urgentBanner
                        timeline
                        share
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("记得吃")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { vm.notify() } label: { Image(systemName: "hand.tap.fill") }
                        .accessibilityLabel("试一下提醒节奏")
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.90, green: 0.94, blue: 0.99)], startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天的药，\n吃了没有").font(DoseTheme.title).foregroundStyle(.indigo)
            HStack {
                Text("\(vm.personName) · 按时 \(Int(vm.adherence * 100))%")
                    .font(DoseTheme.body).foregroundStyle(.secondary)
                Spacer()
                Text("已服 \(vm.slots.filter { $0.state == .taken }.count) / \(vm.slots.count)")
                    .font(DoseTheme.body).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var urgentBanner: some View {
        if !vm.urgentMissed.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("漏服了不能自己补", systemImage: "exclamationmark.triangle.fill")
                    .font(DoseTheme.section).foregroundStyle(.white)
                Text(vm.urgentMissed.map { "\($0.medication.name)（\($0.hour):00）" }.joined(separator: "、"))
                    .font(DoseTheme.body)
                Text("请联系开药医生或药师，不要自行加倍。")
                    .font(DoseTheme.body)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天的时间轴").font(DoseTheme.section)
            ForEach(vm.slots) { slot in
                row(slot)
                if slot.id != vm.slots.last?.id { Divider() }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }

    private func row(_ slot: DoseSlot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d:00", slot.hour))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(slot.medication.name) \(slot.medication.dose)").font(DoseTheme.body)
                HStack(spacing: 6) {
                    Text(slot.state.label).font(.caption).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(color(for: slot.state), in: Capsule())
                    if slot.medication.withFood { Text("饭后").font(.caption).foregroundStyle(.secondary) }
                    if let who = slot.confirmedBy { Text("\(who)确认").font(.caption).foregroundStyle(.secondary) }
                }
                if slot.state == .missed {
                    Text(vm.engine.advice(for: slot).detail).font(.footnote).foregroundStyle(color(for: slot.state))
                }
            }
            Spacer()
            action(for: slot)
        }
    }

    @ViewBuilder
    private func action(for slot: DoseSlot) -> some View {
        if slot.state == .taken {
            Button { vm.simulateMissed(slot) } label: {
                Image(systemName: "arrow.uturn.backward.circle").font(.title2)
            }
            .accessibilityLabel("撤销 \(slot.medication.name) 的确认")
        } else {
            Button { vm.confirm(slot, by: "家属") } label: {
                Image(systemName: slot.state == .pending ? "checkmark.circle.fill" : "questionmark.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("确认 \(slot.medication.name) 已服用")
        }
    }

    private var share: some View {
        ShareLink(item: vm.report) {
            Label("把今日日报发给子女", systemImage: "square.and.arrow.up")
                .font(DoseTheme.body)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }

    private var disclaimer: some View {
        Text("用药问题请以医生与说明书为准。这个 App 只负责提醒与记录，不给用药建议，也不能替代药盒与家人。")
            .font(.footnote).foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func color(for state: DoseState) -> Color {
        switch state {
        case .pending: Color.gray
        case .taken: Color.green
        case .missed: Color.red
        case .skippedByDoctor: Color.blue
        }
    }
}
