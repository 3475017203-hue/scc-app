import Foundation

/// 从室内到路边（或车上）的每一段路。
struct TerrainSegment: Identifiable, Hashable, Codable {
    enum Surface: String, Codable, CaseIterable {
        case flat = "平地"
        case mud = "泥地"
        case tile = "瓷砖"
        case grass = "草地"
        case gravel = "碎石"

        var frictionNote: String? {
            switch self {
            case .mud: "泥地极易打滑，建议先铺木板或砖块"
            case .tile: "瓷砖上移动务必垫布，否则腿上使不上劲"
            case .gravel: "碎石路颠簸，脊柱或髋部伤要格外托稳"
            case .grass, .flat: nil
            }
        }
    }

    let id: UUID
    let name: String
    /// 长度（米）
    let length: Double
    /// 坡度百分比，10 = 10%（约 5.7 度）
    let slopePercent: Double
    let steps: Int
    /// 最窄处宽度（厘米）
    let narrowestCm: Double
    let surface: Surface
    /// 是否需要侧身通过
    let requiresSideways: Bool

    init(id: UUID = UUID(), name: String, length: Double, slopePercent: Double, steps: Int = 0, narrowestCm: Double = 120, surface: Surface = .flat, requiresSideways: Bool = false) {
        self.id = id
        self.name = name
        self.length = length
        self.slopePercent = slopePercent
        self.steps = steps
        self.narrowestCm = narrowestCm
        self.surface = surface
        self.requiresSideways = requiresSideways
    }

    /// 该段能不能安全通过一张平躺的人或担架
    var isCarryWideEnough: Bool {
        narrowestCm >= 70 && !(steps > 0 && narrowestCm < 80)
    }
}
