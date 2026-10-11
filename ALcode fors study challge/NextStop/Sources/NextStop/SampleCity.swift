import Foundation

enum SampleCity {
    /// 一条真实的县域公交线路：起点在老城区，终点是人民医院
    static let line7 = Route(
        id: "7",
        name: "7 路 · 老城 → 人民医院",
        stops: [
            Stop(id: "s1", name: "西关车站", friction: .noSeat),
            Stop(id: "s2", name: "五金市场", friction: .noSeat),
            Stop(id: "s3", name: "中心广场", friction: .crowdedTransfer),
            Stop(id: "s4", name: "纺织厂", friction: .noisy),
            Stop(id: "s5", name: "一中", friction: .noisy),
            Stop(id: "s6", name: "市医院", friction: .easy)
        ],
        firstDeparture: 5 * 60 + 30,
        lastDeparture: 21 * 60
    )

    /// 末班车：超过发车时间就不该再上车了
    static func lastDepartureRisk(route: Route, nowMinutes: Int) -> String {
        if nowMinutes > route.lastDeparture { return "已经过了末班车时间，别再等。" }
        if nowMinutes > route.lastDeparture - 30 { return "距末班车不到半小时了。" }
        return "还有时间。末班车 \(route.lastDeparture / 60) 点 \(route.lastDeparture % 60) 分。"
    }
}
