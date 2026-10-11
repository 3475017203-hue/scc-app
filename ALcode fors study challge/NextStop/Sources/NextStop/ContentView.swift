import SwiftUI

enum StopTheme {
    static let title = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct ContentView: View {
    @StateObject private var vm = NextStopViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                VStack(spacing: 18) {
                    nextStopCard
                    riskCard
                    controls
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("下一站")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.94, green: 0.97, blue: 1.0), Color(red: 0.88, green: 0.93, blue: 0.99)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var nextStopCard: some View {
        VStack(spacing: 10) {
            Text("下一站").font(StopTheme.section).foregroundStyle(.secondary)
            if vm.isAtDestination {
                Text("到站了").font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.green)
            } else {
                Text(vm.nextStop?.name ?? "——")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                Text("还有 \(vm.stopsLeft) 站").font(StopTheme.body).foregroundStyle(.secondary)
                if let next = vm.nextStop, next.friction != .easy {
                    Text(next.friction.note).font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vm.plan.risk.rawValue)
                .font(StopTheme.section).foregroundStyle(.white)
            Text("震动方式：\(vm.hapticName)").font(StopTheme.body).foregroundStyle(.white.opacity(0.9))
            ForEach(vm.plan.actions, id: \.self) { action in
                Text("· \(action)").font(StopTheme.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color(for: vm.plan.risk), in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Toggle("我能听清报站", isOn: $vm.canHearAnnouncements)
                .font(StopTheme.body)
                .onChange(of: vm.canHearAnnouncements) { _, _ in vm.refresh() }

            HStack {
                Button {
                    vm.rewind()
                } label: {
                    Image(systemName: "arrow.uturn.backward").font(.title2)
                }
                .buttonStyle(.bordered)
                Button {
                    vm.advance(hearingAnnouncement: vm.canHearAnnouncements)
                } label: {
                    Label("到站了", systemImage: "arrow.right.circle.fill").font(StopTheme.section)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                Button {
                    vm.advance(hearingAnnouncement: false)
                } label: {
                    Image(systemName: "ear.slash").font(.title2)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("到站了，但我没听见报站")
            }
            Text("当前：\(vm.currentStop.name)　目的：\(vm.destination.name)")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    private func color(for risk: RideRisk) -> Color {
        switch risk {
        case .smooth: Color.green
        case .mightMiss: Color.orange
        case .willLikelyMiss: Color.red
        }
    }
}
