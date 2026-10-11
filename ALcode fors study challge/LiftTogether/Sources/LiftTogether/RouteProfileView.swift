import SwiftUI

/// 坡度剖面图：一眼看出哪段陡、哪段窄。
/// 现场的人看不懂分数，但看得懂「这里陡」。
struct RouteProfileView: View {
    let segments: [TerrainSegment]
    let chosen: TerrainSegment?

    var body: some View {
        Canvas { context, size in
            let maxSlope = max(segments.map { abs($0.slopePercent) }.max() ?? 20, 20)
            let width = size.width / CGFloat(max(segments.count, 1))

            var base = Path()
            base.move(to: CGPoint(x: 0, y: size.height))
            base.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(base, with: .color(.black.opacity(0.2)), lineWidth: 1)

            for (index, segment) in segments.enumerated() {
                let height = CGFloat(abs(segment.slopePercent) / maxSlope) * (size.height * 0.8)
                let bar = CGRect(x: CGFloat(index) * width + 4, y: size.height - height, width: width - 8, height: height)
                let isChosen = chosen?.id == segment.id
                context.fill(Path(roundedRect: bar, cornerRadius: 6), with: .color(isChosen ? .green : barColor(segment)))
                if segment.steps > 0 {
                    let note = Text("\(segment.steps) 级").font(.caption2).foregroundColor(.secondary)
                    context.draw(note, at: CGPoint(x: CGFloat(index) * width + width / 2, y: size.height - height - 12))
                }
            }
        }
        .frame(height: 110)
        .accessibilityLabel("路径坡度剖面：共 \(segments.count) 段")
    }

    private func barColor(_ segment: TerrainSegment) -> Color {
        if segment.steps > 0 || segment.requiresSideways { return .orange }
        if segment.slopePercent >= 15 { return .red }
        if segment.surface == .mud || segment.surface == .gravel { return .purple }
        return .gray.opacity(0.5)
    }
}

extension View {
    func liftCard() -> some View {
        padding(16)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.blue.opacity(0.2), lineWidth: 1))
    }
}
