import SwiftUI

/// 把震动节奏画出来。
///
/// 这是整个作品最要紧的一块设计：
/// 听障用户没法"听"设备响没响，只能靠事后回忆确认。
/// 于是节奏**看得见**——设计者能调，用户能学，评委能在视频里一眼看懂。
struct HapticWaveformView: View {
    let pattern: HapticPattern
    @State private var playhead: Double = 0
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 12) {
            Canvas { context, size in
                let duration = max(pattern.totalDuration, 0.6)
                let midY = size.height / 2

                var axis = Path()
                axis.move(to: CGPoint(x: 0, y: midY))
                axis.addLine(to: CGPoint(x: size.width, y: midY))
                context.stroke(axis, with: .color(.black.opacity(0.25)), lineWidth: 1)

                for tap in pattern.taps {
                    let x = CGFloat(tap.time / duration) * size.width
                    let height = CGFloat(tap.intensity) * (size.height * 0.8)
                    let bar = CGRect(x: x - 6, y: midY - height / 2, width: 12, height: height)
                    let base = colorFor(pattern.event)
                    let color = playhead >= tap.time ? base : base.opacity(0.3)
                    context.fill(Path(roundedRect: bar, cornerRadius: 6), with: .color(color))
                }

                if isPlaying {
                    let x = CGFloat(playhead / duration) * size.width
                    var head = Path()
                    head.move(to: CGPoint(x: x, y: 0))
                    head.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(head, with: .color(.black.opacity(0.35)), lineWidth: 2)
                }
            }
            .frame(height: 90)
            .accessibilityLabel("\(pattern.event.label)的震动节奏，共 \(pattern.taps.count) 下")

            HStack {
                Button { animate() } label: {
                    Label(isPlaying ? "停止" : "播放节奏", systemImage: isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Text("\(pattern.taps.count) 下 · 强度 \(String(format: "%.1f", pattern.totalIntensity))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .font(.body)
        }
        .onDisappear { isPlaying = false }
    }

    private func colorFor(_ event: SoundEvent) -> Color {
        switch event {
        case .knock: .blue
        case .babyCry: .pink
        case .kettle: .orange
        case .smokeAlarm: .red
        case .waterLeak: .teal
        case .unknown: .gray
        }
    }

    private func animate() {
        guard !isPlaying else {
            isPlaying = false
            return
        }
        isPlaying = true
        playhead = 0
        withAnimation(.linear(duration: pattern.totalDuration)) {
            playhead = pattern.totalDuration
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pattern.totalDuration) {
            isPlaying = false
        }
    }
}
