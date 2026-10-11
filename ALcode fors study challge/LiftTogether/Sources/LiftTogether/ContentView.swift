import SwiftUI

enum LiftTheme {
    static let title = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let section = Font.system(size: 21, weight: .bold, design: .rounded)
    static let body = Font.system(size: 19, weight: .medium, design: .rounded)
}

struct ContentView: View {
    @State private var injury: InjuryCase = .spineSuspected
    @State private var people = 4
    @State private var plan: MovePlan?
    @State private var sample = SampleEnvironment.all
    @State private var timer = MoveTimer()
    @State private var speaker = SilentLiftSpeaker()

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        injuryPicker
                        peoplePicker
                        routeCard
                        if let plan { planCard(plan) }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("合力")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { regenerate() }
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.93, green: 0.95, blue: 0.99), Color(red: 0.86, green: 0.90, blue: 0.97)], startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("救护车到之前，\n把人挪到能上车的地方").font(LiftTheme.title).foregroundStyle(.blue)
            Text("不知道背、不知道几个人、不知道哪条路能走——现场最缺的是这三件事。")
                .font(LiftTheme.body).foregroundStyle(.secondary)
        }
    }

    private var injuryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("① 什么情况").font(LiftTheme.section)
            ForEach(InjuryCase.allCases) { item in
                Button {
                    injury = item
                    regenerate()
                } label: {
                    HStack {
                        Image(systemName: injury.id == item.id ? "largecircle.fill.circle" : "circle")
                        Text(item.rawValue)
                        Spacer()
                        if item.isLifeThreatening {
                            Text("危重").font(.caption).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.red, in: Capsule())
                        }
                    }
                    .font(LiftTheme.body)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCard()
    }

    private var peoplePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("② 现在身边有几个人").font(LiftTheme.section)
            Stepper("可用人手：\(people) 人", value: $people, in: 1...10)
                .font(LiftTheme.body)
                .onChange(of: people) { _, _ in regenerate() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCard()
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("③ 从这里到路边，有这些路").font(LiftTheme.section)
            RouteProfileView(segments: sample, chosen: plan?.route?.segment)
            ForEach(sample) { segment in
                HStack {
                    Image(systemName: "arrow.right.circle").foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.name).font(LiftTheme.body)
                        Text(summary(segment)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    badge(for: segment)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCard()
    }

    @ViewBuilder
    private func badge(for segment: TerrainSegment) -> some View {
        if plan?.route?.segment.id == segment.id {
            Text("选它").font(.caption).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.green, in: Capsule())
        } else if RouteScorer().score(segment, for: injury) == nil {
            Text("危险").font(.caption).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.red, in: Capsule())
        }
    }

    private func planCard(_ plan: MovePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.headline)
                .font(LiftTheme.section)
                .foregroundStyle(plan.hasEnoughPeople ? Color.green : Color.orange)
            block("怎么动手", plan.steps)
            block("谁做什么", plan.people.map(\.rawValue))
            block("绝对不要", plan.doNot, color: .red)
            block("等车时先做这几件事", plan.whileWaiting, color: .blue)

            timerRow
            briefRow(plan)

            ShareLink(item: shareText(plan)) {
                Label("发给正在赶来的邻居 / 家属", systemImage: "square.and.arrow.up")
                    .font(LiftTheme.body)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCard()
    }

    private var timerRow: some View {
        HStack {
            Button {
                if timer.isRunning {
                    _ = timer.finish()
                } else {
                    timer.start()
                }
            } label: {
                Label(timer.isRunning ? "结束搬运" : "开始搬运", systemImage: timer.isRunning ? "stop.fill" : "play.fill")
                    .font(LiftTheme.body)
            }
            .buttonStyle(.borderedProminent)

            Text(timer.elapsed.map { String(format: "%.0f 秒", $0) } ?? "未开始")
                .font(LiftTheme.body).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func briefRow(_ plan: MovePlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("免看模式：现场直接念给你听").font(.headline)
            Button {
                speaker.speak(LiftBrief(plan: plan).speechText)
            } label: {
                Label("读完整方案", systemImage: "speaker.wave.2.fill").font(LiftTheme.body)
            }
            .buttonStyle(.bordered)
            Button {
                speaker.speak(LiftBrief(plan: plan).urgentSpeech)
            } label: {
                Label("只念最要紧的三句", systemImage: "bolt.fill").font(LiftTheme.body)
            }
            .buttonStyle(.bordered)
            Text(timer.report()).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func block(_ title: String, _ items: [String], color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                Text("· \(item)").font(LiftTheme.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summary(_ segment: TerrainSegment) -> String {
        var parts = ["\(Int(segment.length)) 米"]
        if segment.slopePercent >= 1 { parts.append("坡 \(Int(segment.slopePercent))%") }
        if segment.steps > 0 { parts.append("\(segment.steps) 级台阶") }
        parts.append(segment.surface.rawValue)
        return parts.joined(separator: " · ")
    }

    private func shareText(_ plan: MovePlan) -> String {
        var lines = ["【合力 · 搬运方案】\(plan.injury.rawValue)"]
        lines.append(plan.headline)
        lines.append("怎么做：" + plan.steps.joined(separator: "；"))
        lines.append("分工：" + plan.people.map(\.rawValue).joined(separator: "；"))
        lines.append("不要：" + plan.doNot.joined(separator: "；"))
        return lines.joined(separator: "\n")
    }

    private func regenerate() {
        plan = PlanGenerator().plan(for: injury, segments: sample, availablePeople: people)
    }
}
