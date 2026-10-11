import SwiftUI

enum GuardTheme {
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
                        verdictCard
                        voiceCard
                        if let plan = vm.plan { escalationCard(plan) }
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("别怕")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { demoMenu }
            }
        }
    }

    private var demoMenu: some View {
        Menu {
            Button("演示：真的起不来") {
                vm.ingest(samples: SampleMotion.fallAndStill())
                vm.runVoiceCheck(responses: [false, false, false])
            }
            Button("演示：摔一下自己起来了") {
                vm.ingest(samples: SampleMotion.fallAndRecover())
                vm.runVoiceCheck(responses: [true])
            }
        } label: {
            Image(systemName: "play.circle.fill")
        }
        .accessibilityLabel("演示两种跌倒")
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.94, green: 0.96, blue: 1.0), Color(red: 0.87, green: 0.90, blue: 0.97)], startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("摔了，先问一句，\n再决定要不要叫人").font(GuardTheme.title).foregroundStyle(.indigo)
            Text("独居老人跌倒后的黄金几小时，绝大多数不是死于伤，而是没人发现。")
                .font(GuardTheme.body).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var verdictCard: some View {
        if let v = vm.verdict {
            VStack(alignment: .leading, spacing: 10) {
                Label(v.phase.rawValue, systemImage: icon(for: v.phase))
                    .font(GuardTheme.section).foregroundStyle(.white)
                ForEach(v.reasons, id: \.self) { reason in
                    Text("· \(reason)").font(GuardTheme.body)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color(for: v.phase), in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.walk.motion").font(.system(size: 40))
                Text("没有检测到跌倒").font(GuardTheme.section)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    @ViewBuilder
    private var voiceCard: some View {
        if !vm.askedQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("先问一句，别急着叫人").font(GuardTheme.section)
                ForEach(Array(vm.askedQuestions.enumerated()), id: \.offset) { index, question in
                    voiceRow(question: question, index: index)
                }
                if vm.shouldEscalate {
                    Text("三次都没有回应 —— 该叫人了。").font(GuardTheme.body).foregroundStyle(.red)
                } else if vm.responses.contains(true) {
                    Text("有回应，说明人没事 —— 升级到此为止，不打扰任何人。")
                        .font(GuardTheme.body).foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func voiceRow(question: String, index: Int) -> some View {
        let answered = vm.responses.indices.contains(index)
        let responded = answered ? vm.responses[index] : false
        return HStack(alignment: .top) {
            Image(systemName: answered ? "checkmark.circle.fill" : "speaker.wave.2.fill")
                .foregroundStyle(answered ? Color.green : Color.orange)
            Text(question).font(GuardTheme.body)
            Spacer()
            if answered {
                Text(responded ? "有回应" : "没有回应").font(.caption)
                    .foregroundStyle(responded ? Color.green : Color.red)
            }
        }
    }

    private func escalationCard(_ plan: EscalationPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("静默升级（约 \(Int(plan.totalWaitSeconds / 60)) 分钟内依次联系）").font(GuardTheme.section)
            ForEach(plan.steps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(step.id). \(step.target)").font(GuardTheme.body).bold()
                        Spacer()
                        Text(step.tier.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(step.channel).font(.caption).foregroundStyle(.secondary)
                    Text(step.message).font(.footnote).foregroundStyle(.secondary).padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("未授权的联系人会被跳过：邻里之间不该因为一次误报产生矛盾。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }

    private var disclaimer: some View {
        Text("这不是报警器，也不能替代呼叫器、手环与 120。这里的价值是：把「可能出事」变成「有人被叫到了」。")
            .font(.footnote).foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func color(for phase: FallPhase) -> Color {
        switch phase {
        case .needHelp: Color.red
        case .recovered: Color.orange
        case .idle: Color.gray
        }
    }

    private func icon(for phase: FallPhase) -> String {
        switch phase {
        case .needHelp: "exclamationmark.triangle.fill"
        case .recovered: "figure.walk"
        case .idle: "checkmark.circle"
        }
    }
}
