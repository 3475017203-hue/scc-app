import Foundation

/// 施药记录本地存储（JSON，不联网）。
/// 田间常无网络，且这些数据没有必要上云——存在手机里最安心。
@MainActor
final class ApplicationStore: ObservableObject {
    @Published private(set) var applications: [Application] = []
    @Published private(set) var storageError: String?

    private let filename = "applications.json"

    init() { load() }

    func add(_ application: Application) {
        applications.append(application)
        persist()
    }

    func remove(_ application: Application) {
        applications.removeAll { $0.id == application.id }
        persist()
    }

    func applications(for crop: Crop) -> [Application] {
        applications.filter { $0.crop.id == crop.id }.sorted { $0.appliedOn > $1.appliedOn }
    }

    // MARK: - 持久化

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(filename)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(applications)
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "本机保存失败：\(error.localizedDescription)"
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            applications = try JSONDecoder().decode([Application].self, from: data)
            storageError = nil
        } catch {
            storageError = "读取历史记录失败：\(error.localizedDescription)"
        }
    }
}
