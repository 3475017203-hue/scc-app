import SwiftUI

/// 就诊卡的"大字模式"：医生站在 1 米外也能一眼读完。
struct VisitCardView: View {
    let card: VisitCard
    var onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @StateObject private var coach = SpeechCoach()
    @State private var audience: SpeechCoach.Audience = .doctor
    @State private var showBrief = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    urgencyBanner
                    headline
                    demographics
                    department
                    if !card.bodySpots.isEmpty { bodySpotsSection }
                    advisories
                    unresolvedSection
                    dialectBridgeList
                    plainLanguage
                    readAloudPanel
                }
                .padding(20)
                .scaleEffect(scale, anchor: .topLeading)
            }
            .background(ElderTheme.warmBackground.ignoresSafeArea())
            .navigationTitle("就诊卡")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成", action: onClose)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        withAnimation { scale = scale >= 1.4 ? 1.0 : scale + 0.2 }
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                    .accessibilityLabel("放大或缩小字号")

                    ShareLink(item: card.plainText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("分享给家属")

                    Button {
                        showBrief = true
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                    .accessibilityLabel("生成家属版一页纸")
                }
            }
            .sheet(isPresented: $showBrief) {
                CaregiverBriefView(card: card)
            }
        }
    }

    private var urgencyBanner: some View {
        Text(card.pathway.urgency.label)
            .font(ElderTheme.sectionTitle)
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ElderTheme.color(for: card.pathway.urgency), in: RoundedRectangle(cornerRadius: 12))
    }

    private var headline: some View {
        Text(card.headline)
            .font(ElderTheme.huge)
            .foregroundStyle(.brown)
            .accessibilityLabel("主诉：\(card.headline)")
    }

    private var demographics: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(card.patient.nickname) · \(card.patient.age) 岁 · \(card.patient.gender) · 讲\(card.patient.dialect.rawValue)")
                .font(ElderTheme.sectionTitle)
            if !card.patient.medications.isEmpty {
                Text("在服药物：\(card.patient.medications.joined(separator: "、"))").font(ElderTheme.body)
            }
            if !card.patient.chronicConditions.isEmpty {
                Text("既往病史：\(card.patient.chronicConditions.joined(separator: "、"))").font(ElderTheme.body)
            }
            if !card.patient.allergies.isEmpty {
                Text("过敏：\(card.patient.allergies.joined(separator: "、"))").font(ElderTheme.body)
            }
            if !card.onsets.isEmpty {
                Text("病程：\(card.onsets.joined(separator: "、"))").font(ElderTheme.body)
            }
        }
        .card()
    }

    private var department: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("建议去：\(card.pathway.department)").font(ElderTheme.sectionTitle)
            Text(card.pathway.departmentRationale).font(.callout).foregroundStyle(.secondary)
        }
        .card()
    }

    private var bodySpotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("老人指认的位置").font(ElderTheme.sectionTitle)
            ForEach(card.bodySpots) { spot in
                HStack {
                    Image(systemName: spot.region.icon).foregroundStyle(.orange)
                    Text(spot.region.doctorText).font(ElderTheme.body).bold()
                    Spacer()
                    Text(spot.display).font(ElderTheme.body).foregroundStyle(.secondary)
                }
                Text("· \(spot.region.hint)").font(.callout).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var advisories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("请医生重点看").font(ElderTheme.sectionTitle)
            ForEach(card.pathway.advisories, id: \.self) { Text($0).font(ElderTheme.body) }
        }
        .card()
    }

    @ViewBuilder
    private var unresolvedSection: some View {
        if !card.unresolved.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("需医生补充问诊").font(ElderTheme.sectionTitle)
                Text("这些说法系统没能归类，已如实转写，不做猜测。")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(card.unresolved, id: \.self) { Text("「\($0)」").font(ElderTheme.body) }
            }
            .card()
        }
    }

    /// 作品的核心：让医生看见"他实际是怎么说的"。
    private var dialectBridgeList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("病人原话 → 医学词").font(ElderTheme.sectionTitle)
            ForEach(card.reportedSymptoms) { segment in
                HStack {
                    Text("「\(segment.source)」")
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").foregroundStyle(.orange)
                    Text(segment.standard).font(ElderTheme.body).bold()
                    Spacer()
                }
            }
        }
        .card()
    }

    private var plainLanguage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("给老人自己看").font(ElderTheme.sectionTitle)
            ForEach(card.pathway.plainLanguage, id: \.self) { Text("· \($0)").font(ElderTheme.body) }
        }
        .card()
    }

    /// 一张卡，三种读法 —— 这是本作品与"翻译 App"的根本差别。
    private var readAloudPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("读给谁听").font(ElderTheme.sectionTitle)
            Picker("朗读对象", selection: $audience) {
                Text("老人").tag(SpeechCoach.Audience.patient)
                Text("医生").tag(SpeechCoach.Audience.doctor)
                Text("子女").tag(SpeechCoach.Audience.family)
            }
            .pickerStyle(.segmented)
            Button {
                coach.state == .speaking ? coach.stop() : coach.speak(coach.script(for: card, audience: audience))
            } label: {
                Label(coach.state == .speaking ? "停止" : "朗读这张卡",
                      systemImage: coach.state == .speaking ? "stop.fill" : "speaker.wave.2.fill")
                    .font(ElderTheme.sectionTitle)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
        }
        .card()
    }
}
