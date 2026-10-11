import Foundation

/// 核心算法：**最后一次施药日 + 安全间隔天数 = 最早可采收日**。
///
/// 为什么必须用"最后一次"：同一茬菜往往要打两三遍药，
/// 很多人只按第一次算日子，结果直接超采——这是农残超标最常见的成因。
enum IntervalEngine {
    struct UnknownInterval: LocalizedError {
        let subject: String
        var errorDescription: String? {
            "没有读到\(subject)的安全间隔期，我不能替你猜。请拍清楚标签，或手动输入天数。"
        }
    }

    static func window(for application: Application,
                       calendar: Calendar = .current) throws -> HarvestWindow {
        guard let days = application.label.safetyIntervalDays.dayCount else {
            throw UnknownInterval(subject: application.crop.name)
        }
        let earliest = calendar.date(byAdding: .day, value: days, to: application.appliedOn)
            ?? application.appliedOn
        return HarvestWindow(earliestHarvestDate: earliest,
                             intervalDays: days,
                             appliedOn: application.appliedOn)
    }

    /// 同一作物多次施药 → 以**最后一次**为准。
    static func window(for applications: [Application],
                       crop: Crop,
                       calendar: Calendar = .current) throws -> HarvestWindow {
        let sameCrop = applications.filter { $0.crop.id == crop.id }
        guard let latest = sameCrop.max(by: { $0.appliedOn < $1.appliedOn }) else {
            throw UnknownInterval(subject: crop.name)
        }
        return try window(for: latest, calendar: calendar)
    }

    static func violationCount(applications: [Application],
                               harvestedDates: [Date],
                               calendar: Calendar = .current) -> Int {
        harvestedDates.filter { date in
            applications.contains { $0.isViolation(harvestedOn: date, calendar: calendar) }
        }.count
    }
}

extension Application {
    func isViolation(harvestedOn: Date, calendar: Calendar = .current) -> Bool {
        guard let window = try? IntervalEngine.window(for: self, calendar: calendar) else { return false }
        return window.isViolation(harvestedOn: harvestedOn, calendar: calendar)
    }
}
