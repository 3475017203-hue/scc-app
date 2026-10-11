import SwiftUI

/// 家属版：一屏说清"现在什么情况、要做什么、别做什么"。
/// 就诊卡是给医生的，这张是给不在场的子女看的——避免两个人各说各话。
struct CaregiverBriefView: View {
    let card: VisitCard
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coach = SpeechCoach()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    todo
                    cautions
                    share
                }
                .padding(20)
            }
            .background(ElderTheme.warmBackground.ignoresSafeArea())
            .navigationTitle("给家属的一页纸")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.pathway.urgency.label)
                .font(.headline).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(ElderTheme.color(for: card.pathway.urgency), in: Capsule())
            Text(card.headline).font(ElderTheme.bigTitle).foregroundStyle(.brown)
            Text("建议去\(card.pathway.department)。")
                .font(ElderTheme.sectionTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var todo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("要做的三件事").font(ElderTheme.sectionTitle)
            checklist(card.pathway.urgency == .emergency || card.pathway.urgency == .urgent
                      ? "立刻陪老人去急诊，路上别让老人自己走"
                      : "这几天内带老人去\(card.pathway.department)")
            checklist("带上：医保卡、既往病历、正在吃的药（含保健品）")
            checklist("把就诊卡给医生看，并口头复述一次主诉，确认没听错")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var cautions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("别做这些").font(ElderTheme.sectionTitle)
            if card.pathway.urgency >= .urgent {
                checklist("不要自己开车送医，叫 120 更安全", crossed: true)
            }
            checklist("不要因为老人说忍一忍就改期复查", crossed: true)
            checklist("不要在没问医生前自行加减药", crossed: true)
            if !card.patient.medications.isEmpty {
                Text("老人目前在吃：\(card.patient.medications.joined(separator: "、"))")
                    .font(ElderTheme.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var share: some View {
        VStack(spacing: 12) {
            ShareLink(item: card.plainText) {
                Label("转发给其他家属", systemImage: "square.and.arrow.up")
                    .font(ElderTheme.sectionTitle)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)

            Button {
                coach.speak(coach.script(for: card, audience: .family))
            } label: {
                Label("读给我听", systemImage: "speaker.wave.2.fill")
                    .font(ElderTheme.sectionTitle)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
    }

    private func checklist(_ text: String, crossed: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: crossed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(crossed ? Color.red : Color.green)
            Text(text)
                .font(ElderTheme.body)
                .strikethrough(crossed)
                .foregroundStyle(crossed ? Color.secondary : Color.primary)
        }
    }
}
