import SwiftUI

enum ChargeTheme {
    static let title = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct ContentView: View {
    @State private var risk: ChargeRisk = .normal
    @State private var reasons: [String] = []
    @State private var smell = false
    @State private var floor = 5

    private let building = Building(name: "阳光小区 3 号楼", floors: 6,
                                    corridorLengths: [8, 9, 9, 9, 10],
                                    corridorBlocked: true, hasElevator: true)

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        riskCard
                        smellToggle
                        evacuationCard
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("楼道有声")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { demoMenu }
            }
            .onAppear { evaluate(.normal) }
        }
    }

    private var demoMenu: some View {
        Menu {
            Button("正常充电") { evaluate(.normal) }
            Button("充电器老化") { evaluate(.aging) }
            Button("疑似异常") { evaluate(.suspect) }
            Button("疑似失控前兆") { evaluate(.dangerous) }
        } label: {
            Image(systemName: "play.circle.fill")
        }
        .accessibilityLabel("演示四种充电状态")
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.98, green: 0.95, blue: 0.92), Color(red: 0.95, green: 0.89, blue: 0.84)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("楼道里那点声音，\n是不是不对劲").font(ChargeTheme.title).foregroundStyle(.red)
            Text("电动车进楼充电是各地整治的重点，也是楼道火灾最常见的人为原因。这件事的第一步，是让人先察觉到。")
                .font(ChargeTheme.body).foregroundStyle(.secondary)
        }
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(risk.rawValue, systemImage: icon)
                .font(ChargeTheme.section).foregroundStyle(.white)
            ForEach(reasons, id: \.self) { reason in
                Text("· \(reason)").font(ChargeTheme.body)
            }
            if risk == .dangerous {
                Text("现在就去叫人。不要试图自己搬动或拔插头——热失控的电池被移动或挤压，可能立刻起火。")
                    .font(ChargeTheme.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(for: risk), in: RoundedRectangle(cornerRadius: 18))
    }

    private var smellToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("现场能确认的线索").font(ChargeTheme.section)
            Toggle("闻到焦糊味", isOn: $smell)
                .font(ChargeTheme.body)
                .onChange(of: smell) { _, _ in reevaluate() }
            Text("焦糊味是最强的信号——任何麦克风都测不到它，但人能闻到。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    private var evacuationCard: some View {
        let route = EvacuationPlanner().route(from: floor, in: building)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("撤离怎么走").font(ChargeTheme.section)
                Spacer()
                Stepper("\(floor) 层", value: $floor, in: 1...building.floors).labelsHidden()
                Text("\(floor) 层").font(ChargeTheme.body)
            }
            ForEach(route.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(ChargeTheme.body).foregroundStyle(.red)
            }
            ForEach(route.steps, id: \.self) { step in
                Text("· \(step)").font(ChargeTheme.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("这不是火灾报警器，也不接任何电气监测。手机拿不到电流、电压与温度数据——")
                .font(.footnote)
            Text("这个作品只做两件事：把楼道里的异常听出来，和在真出事时告诉你怎么下楼。")
                .font(.footnote).bold()
        }
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func evaluate(_ kind: SampleAudio.Kind) {
        current = kind
        reevaluate()
    }

    @State private var current: SampleAudio.Kind = .normal

    private func reevaluate() {
        let signature = SampleAudio.signature(for: current, reportedSmell: smell)
        let result = ChargeClassifier().risk(signature)
        risk = result.0
        reasons = result.1
    }

    private var color: Color { color(for: risk) }

    private var icon: String {
        switch risk {
        case .normal: "checkmark.circle.fill"
        case .aging: "wrench.and.screwdriver.fill"
        case .suspect: "exclamationmark.triangle.fill"
        case .dangerous: "flame.fill"
        }
    }

    private func color(for r: ChargeRisk) -> Color {
        switch r {
        case .normal: Color.green
        case .aging: Color.orange
        case .suspect: Color.deepOrange
        case .dangerous: Color.red
        }
    }
}
