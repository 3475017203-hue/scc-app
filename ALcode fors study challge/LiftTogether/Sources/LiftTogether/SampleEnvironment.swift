import Foundation

/// 一个真实的农村三层自建房场景：从卧室到院门外的土坡。
enum SampleEnvironment {
    static let all: [TerrainSegment] = [
        TerrainSegment(name: "卧室到楼梯口", length: 4, slopePercent: 0, narrowestCm: 82, surface: .tile),
        TerrainSegment(name: "楼梯下到一楼", length: 6, slopePercent: 0, steps: 12, narrowestCm: 68, surface: .tile),
        TerrainSegment(name: "一楼到院门（水泥地）", length: 15, slopePercent: 4, narrowestCm: 120, surface: .flat),
        TerrainSegment(name: "院门到土路（12% 缓坡）", length: 22, slopePercent: 12, narrowestCm: 200, surface: .grass),
        TerrainSegment(name: "侧门小路（更近但 18% 陡坡泥地）", length: 8, slopePercent: 18, narrowestCm: 90, surface: .mud)
    ]
}
