import Foundation

/// 站点与路线。不依赖任何地图 SDK 的纯数据模型——
/// 一个县城的老线路数据，官方 API 往往根本没有。
struct Route: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let stops: [Stop]
    /// 首末班时间（分钟数，从 0:00 起算），用于末班车预警
    let firstDeparture: Int
    let lastDeparture: Int

    func index(of stopID: String) -> Int? {
        stops.firstIndex { $0.id == stopID }
    }
}

struct Stop: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    /// 老年人在这一站的真实困难度（0 最好，3 最难）
    let friction: Friction

    enum Friction: Int, Codable, CaseIterable {
        case easy          // 有座椅、有站台
        case noSeat        // 没座位
        case noisy         // 路边噪声大，报站听不清
        case crowdedTransfer // 需要换乘、人多易走错

        var note: String {
            switch self {
            case .easy: "有座位，下车不挤"
            case .noSeat: "没有座位，得站一路"
            case .noisy: "路边噪声大，报站基本听不清"
            case .crowdedTransfer: "要换乘，人多容易走错"
            }
        }
    }
}
