import SwiftUI

/// "说不清就指一指"——可访问的身体示意图。
/// 实现上不是像素命中测试，而是一组大按钮：老人只需要点得中，
/// 这也是 Switch Control / 肌电辅助设备下最可靠的交互方式。
struct BodyMapView: View {
    @Binding var spots: [BodySpot]
    var onConfirm: () -> Void

    @State private var isFront = true
    @State private var pendingRegion: BodyRegion?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("③ 指一指，哪里不舒服").font(ElderTheme.sectionTitle)
                Spacer()
                Picker("正面或背面", selection: $isFront) {
                    Text("正面").tag(true)
                    Text("背面").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            HStack(alignment: .top, spacing: 16) {
                silhouette
                sidePicker
            }

            if let region = pendingRegion {
                sideChooser(for: region)
            }

            if !spots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已标记：").font(ElderTheme.body)
                    ForEach(spots) { spot in
                        HStack {
                            Image(systemName: spot.region.icon)
                            Text(spot.display).font(ElderTheme.body)
                            Spacer()
                            Button {
                                spots.removeAll { $0.id == spot.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.title2)
                            }
                            .accessibilityLabel("移除 \(spot.display)")
                        }
                    }
                    Button(action: onConfirm) {
                        Text("生成就诊卡")
                            .font(ElderTheme.sectionTitle)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brown)
                }
            }
        }
        .card()
    }

    /// 一个由大按钮拼成的人形示意图 —— 每个部位都是可点的。
    private var silhouette: some View {
        VStack(spacing: 8) {
            button(.head)
            HStack(spacing: 8) {
                button(.eye)
                button(.ear)
            }
            button(.throat)
            button(.chest)
            button(.upperAbdomen)
            button(.lowerAbdomen)
            HStack(spacing: 8) {
                button(.arm)
                Spacer()
                button(isFront ? .back : .leg)
            }
            button(.joint)
            HStack(spacing: 8) {
                button(.leg)
                Spacer()
                button(.skin)
            }
        }
        .frame(width: 150)
    }

    private func button(_ region: BodyRegion) -> some View {
        let selected = spots.contains { $0.region == region }
        return Button {
            pendingRegion = region
        } label: {
            VStack(spacing: 4) {
                Image(systemName: region.icon).font(.title2)
                Text(region.label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 4)
            .background(selected ? Color.orange.opacity(0.35) : Color.white.opacity(0.8),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.orange : Color.brown.opacity(0.2),
                        lineWidth: selected ? 3 : 1))
        }
        .accessibilityLabel("标记\(region.label)")
    }

    /// 左右侧对半边症状很关键（中风、肾结石都是典型）。
    private var sidePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("哪一侧？").font(ElderTheme.body)
            ForEach(BodyRegion.Side.allCases, id: \.self) { side in
                Button {
                    guard let region = pendingRegion else { return }
                    spots.append(BodySpot(region: region, side: side))
                    pendingRegion = nil
                } label: {
                    Text(side.rawValue)
                        .font(ElderTheme.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Text(pendingRegion?.hint ?? "先在左边选部位")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sideChooser(for region: BodyRegion) -> some View {
        HStack {
            Text("「\(region.label)」是\(region == .head || region == .chest ? "整体" : "左、右还是两侧？")")
                .font(ElderTheme.body)
            Spacer()
            Button("就按整体记") {
                spots.append(BodySpot(region: region, side: .none))
                pendingRegion = nil
            }
            .font(ElderTheme.body)
        }
        .padding(12)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }
}
