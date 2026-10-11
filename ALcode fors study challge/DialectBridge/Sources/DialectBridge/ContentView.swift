import SwiftUI

struct ContentView: View {
    @StateObject private var vm = BridgeViewModel()
    @State private var typedInput = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ElderTheme.warmBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        profileCard
                        inputCard
                        if !vm.segments.isEmpty { confirmationCard }
                        if !vm.fragments.isEmpty { fragmentCard }
                        BodyMapView(spots: $vm.spots) { vm.confirm() }
                        if !vm.segments.isEmpty { symptomGrid }
                        if let error = vm.errorMessage { errorBanner(error) }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("乡音桥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        CorpusView(store: vm.store) { vm.corpusDidChange() }
                    } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .accessibilityLabel("共建词库")
                }
            }
            .sheet(item: Binding(
                get: { vm.stage == .card ? vm.history.first : nil },
                set: { if $0 == nil { vm.reset() } }
            )) { card in
                VisitCardView(card: card) { vm.reset() }
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说不清的难受，\n变成医生看得懂的普通话")
                .font(ElderTheme.bigTitle)
                .foregroundStyle(.brown)
            Text("对着手机说人话 → 自动转成规范医学词 → 生成一张就诊卡")
                .font(ElderTheme.body)
                .foregroundStyle(.brown.opacity(0.75))
        }
    }

    // MARK: - 个人信息

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("① 我是谁").font(ElderTheme.sectionTitle)
            Picker("我讲的话", selection: $vm.patient.dialect) {
                ForEach(DialectRegion.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
            .pickerStyle(.menu)
            .font(ElderTheme.body)
            Text(vm.patient.dialect.hint)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Stepper("年龄：\(vm.patient.age) 岁", value: $vm.patient.age, in: 18...100)
                .font(ElderTheme.body)

            TextField("正在吃的药（逗号分隔）", text: Binding(
                get: { vm.patient.medications.joined(separator: "，") },
                set: { vm.patient.medications = $0.isEmpty ? [] : $0.components(separatedBy: "，").map { $0.trimmingCharacters(in: .whitespaces) } }
            ))
            .textFieldStyle(.roundedBorder)
            .font(ElderTheme.body)
        }
        .card()
    }

    // MARK: - 说 / 指

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("② 说出来").font(ElderTheme.sectionTitle)
            Button {
                vm.listen()
            } label: {
                Label(vm.stage == .listening ? "正在听…" : "按住说：我的心口疼", systemImage: "mic.fill")
                    .font(ElderTheme.sectionTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
            .disabled(vm.stage == .listening)

            Button {
                vm.startDemo()
            } label: {
                Label("演示：\(DemoScenarios.all[vm.demoIndex % DemoScenarios.all.count].persona)",
                      systemImage: "play.circle.fill")
                    .font(ElderTheme.body)
            }
            .buttonStyle(.bordered)

            HStack {
                Button {
                    vm.nextDemo()
                } label: {
                    Label("换一个人物", systemImage: "person.2.fill").font(ElderTheme.body)
                }
                .buttonStyle(.bordered)

                Spacer()

                Toggle("演示模式", isOn: Binding(
                    get: { vm.isScriptedDemo },
                    set: { vm.toggleDemoMode($0) }
                ))
                .font(.footnote)
                .labelsHidden()
                Text("无麦克风时可开").font(.caption2).foregroundStyle(.secondary)
            }

            if !vm.transcript.isEmpty {
                Text("听到：\(vm.transcript)")
                    .font(ElderTheme.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            }

            // 没麦克风、说不清、或家属在旁边——打字走同一条归一化流水线
            HStack {
                TextField("不会说话？让家人打几个字", text: $typedInput)
                    .textFieldStyle(.roundedBorder)
                    .font(ElderTheme.body)
                    .submitLabel(.done)
                    .onSubmit(submitTyped)
                Button("输入", action: submitTyped)
                    .font(ElderTheme.body)
                    .buttonStyle(.bordered)
            }
        }
        .card()
    }

    private func submitTyped() {
        let text = typedInput
        guard !text.isEmpty else { return }
        vm.ingest(text)
        typedInput = ""
    }

    // MARK: - 归一化确认

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("③ 我说得对吗？").font(ElderTheme.sectionTitle)
                Spacer()
                Button("确认") { vm.confirm() }
                    .font(ElderTheme.sectionTitle)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            ForEach(vm.segments) { segment in
                HStack {
                    Image(systemName: segment.term.category.icon).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.source).font(ElderTheme.body).foregroundStyle(.secondary)
                        Text(segment.standard).font(ElderTheme.sectionTitle)
                    }
                    Spacer()
                    if segment.confidence < 1 {
                        Text("听错可能 \(Int((1 - segment.confidence) * 100))%")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Button { vm.remove(segment) } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("删除 \(segment.standard)")
                }
            }
        }
        .card()
    }

    /// 兜底：听不懂的部分不丢弃，转成"要不要是这个？"让老人自己确认。
    private var fragmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这几处没听懂，你看看对不对").font(ElderTheme.sectionTitle)
            ForEach(vm.fragments) { fragment in
                VStack(alignment: .leading, spacing: 8) {
                    Text("「\(fragment.text)」").font(ElderTheme.body).foregroundStyle(.secondary)
                    Text(fragment.note).font(.footnote).foregroundStyle(.secondary)
                    if fragment.candidates.isEmpty {
                        Text("词库里没有相近说法 → 已写进卡片，请医生补充问诊")
                            .font(.footnote).foregroundStyle(.orange)
                    } else {
                        HStack {
                            ForEach(fragment.candidates) { term in
                                Button {
                                    vm.toggle(term)
                                } label: {
                                    Text(term.standard)
                                        .font(ElderTheme.body)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(.orange.opacity(0.2), in: Capsule())
                                }
                            }
                        }
                    }
                }
                Divider()
            }
        }
        .card()
    }

    // MARK: - 不识字/说不清时的兜底：症状卡

    private var symptomGrid: some View {
        // 依赖语料版本号：社区导入新词条后，症状卡立刻重建
        let _ = vm.corpusTick
        VStack(alignment: .leading, spacing: 12) {
            Text("④ 或者直接点").font(ElderTheme.sectionTitle)
            Text("不会说普通话？点一下就行。")
                .font(ElderTheme.body).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(vm.store.terms(for: vm.patient.dialect)) { term in
                    Button {
                        vm.toggle(term)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(term.category.rawValue, systemImage: term.category.icon)
                                .font(.footnote).foregroundStyle(.secondary)
                            Text(term.standard)
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(term.colloquialisms.prefix(2).joined(separator: "·"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(vm.isSelected(term) ? Color.orange.opacity(0.25) : .white.opacity(0.75),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(vm.isSelected(term) ? Color.orange : Color.brown.opacity(0.2), lineWidth: vm.isSelected(term) ? 3 : 1)
                        )
                    }
                    .accessibilityLabel("\(term.standard)，常见说法：\(term.colloquialisms.joined(separator: "、"))")
                }
            }
            Button {
                vm.confirm()
            } label: {
                Text("生成就诊卡（\(vm.segments.count) 项症状\(vm.spots.isEmpty ? "" : " · \(vm.spots.count) 处位置")）")
                    .font(ElderTheme.sectionTitle)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
            .disabled(vm.segments.isEmpty)
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(ElderTheme.body)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func card() -> some View {
        padding(16)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brown.opacity(0.15), lineWidth: 1))
    }
}
