import SwiftUI

enum FoolTheme {
    static let title = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct ContentView: View {
    @StateObject private var vm = GuardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        riskCard
                        actionCard
                        evidenceCard
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("别信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink { CorpusView() } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .accessibilityLabel("共建话术库")
                    demoMenu
                }
            }
        }
    }

    private var demoMenu: some View {
        Menu {
            Button("正常的一通电话") { vm.replay(DemoScenarios.safeCall) }
            Button("可疑的一通电话") { vm.replay(DemoScenarios.suspiciousCall) }
            Button("正在被骗的一通电话") { vm.replay(DemoScenarios.urgentCall) }
        } label: {
            Image(systemName: "play.circle.fill")
        }
        .accessibilityLabel("演示三通电话")
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.98, green: 0.97, blue: 0.94), Color(red: 0.95, green: 0.93, blue: 0.88)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("对方说的话，\n帮你听出不对劲").font(FoolTheme.title).foregroundStyle(.orange)
            Text("骗子的话会一直变，套路结构不会变。我们认的是套路组合，不是某一句话。")
                .font(FoolTheme.body).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var riskCard: some View {
        if let current = vm.current {
            VStack(alignment: .leading, spacing: 8) {
                Text(current.level.label)
                    .font(FoolTheme.section).foregroundStyle(.white)
                Text("提醒方式：\(current.level.hapticName)")
                    .font(FoolTheme.body).foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color(for: current.level), in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "phone").font(.system(size: 40))
                Text("还没有听到什么").font(FoolTheme.section)
                Text("点右上角演示，接一通电话").font(FoolTheme.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        if let current = vm.current, !current.actions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("现在该做什么").font(FoolTheme.section)
                ForEach(current.actions, id: \.self) { action in
                    Text("· \(action)").font(FoolTheme.body)
                }
                ForEach(current.matchedScripts) { script in
                    Text("\(script.rawValue)：\(script.whyDangerous)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    @ViewBuilder
    private var evidenceCard: some View {
        if let current = vm.current, !current.evidence.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("它为什么这么判断").font(FoolTheme.section)
                ForEach(current.evidence, id: \.self) { line in
                    Text("· \(line)").font(.footnote).foregroundStyle(.secondary)
                }
                if current.level == .suspicious {
                    Text("只有一个特征，先别挂电话，也先别转账——再听两句。")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var disclaimer: some View {
        Text("这不是防诈骗软件，也不能拦住电话。它只是在对方说出关键话术时提醒你一句——真遇到事情，96110 和 110 永远是可信的。")
            .font(.footnote).foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func color(for level: RiskLevel) -> Color {
        switch level {
        case .none: Color.green
        case .suspicious: Color.yellow
        case .alerting: Color.orange
        case .urgent: Color.red
        }
    }
}
