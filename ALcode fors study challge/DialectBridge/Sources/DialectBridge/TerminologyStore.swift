import Foundation

/// 词库存储：内置词库 + 社区共建词库，本地持久化。
///
/// 设计约束：**没有任何网络上传**。社区补充的条目只留在这一台设备上，
/// 导诊护士可以用 ShareLink 手动带去审核——这是医疗数据该有的默认姿态。
@MainActor
final class TerminologyStore: ObservableObject {
    @Published private(set) var communityTerms: [MedicalTerm] = []
    /// 待社区医生复核的草稿。**未经复核的条目不会进入词库**——
    /// 这是上一轮竞品对比暴露出的最大短板（我们没有权威背书），
    /// 用流程补：一条说法要生效，得先有一个人为它签字。
    @Published private(set) var pendingDrafts: [CorpusImporter.Draft] = []
    @Published private(set) var lastImportedCount: Int = 0
    @Published private(set) var storageError: String?

    private let filename = "community-terminology.json"

    /// 全部词条：内置 + **已签字的**社区词条
    var all: [MedicalTerm] { Terminology.all + communityTerms }

    var totalCount: Int { all.count }

    func terms(for region: DialectRegion, category: SymptomCategory? = nil) -> [MedicalTerm] {
        all.filter { term in
            let regionOK = term.regions.isEmpty || term.regions.contains(region) || region == .putonghua
            let categoryOK = category.map { term.category == $0 } ?? true
            return regionOK && categoryOK
        }
    }

    // MARK: - 导入

    /// 导入进入**待复核**区，不直接生效。
    @discardableResult
    func importDrafts(_ drafts: [CorpusImporter.Draft]) -> Int {
        pendingDrafts.append(contentsOf: drafts)
        lastImportedCount = drafts.count
        persist()
        return drafts.count
    }

    /// 医生签字后才并入正式词库，并做去重合并
    @discardableResult
    func approve(_ draft: CorpusImporter.Draft) -> Int {
        pendingDrafts.removeAll { $0.id == draft.id }
        let added = mergeIntoCommunity(draft)
        persist()
        return added
    }

    @discardableResult
    func approveAll() -> Int {
        var added = 0
        for draft in pendingDrafts { added += mergeIntoCommunity(draft) }
        pendingDrafts = []
        persist()
        return added
    }

    func reject(_ draft: CorpusImporter.Draft) {
        pendingDrafts.removeAll { $0.id == draft.id }
        persist()
    }

    /// 同一规范词 + 同一说法只保留一条；新说法合并进已有条目。
    private func mergeIntoCommunity(_ draft: CorpusImporter.Draft) -> Int {
        var merged = communityTerms
        guard let idx = merged.firstIndex(where: {
            $0.standard == draft.standard && $0.category == draft.category
        }) else {
            merged.append(draft.term)
            persist()
            return draft.colloquialisms.count
        }
        let existing = merged[idx]
        let newPhrases = draft.colloquialisms.filter { !existing.colloquialisms.contains($0) }
        if newPhrases.isEmpty { return 0 }
        merged[idx] = MedicalTerm(
            existing.id, existing.standard,
            colloquialisms: existing.colloquialisms + newPhrases,
            note: existing.doctorNote, category: existing.category,
            regions: Array(Set(existing.regions + draft.regions)),
            urgency: existing.urgencyOverride
        )
        communityTerms = merged
        return newPhrases.count
    }

    func removeCommunityTerm(id: String) {
        communityTerms.removeAll { $0.id == id }
        persist()
    }

    func reset() {
        communityTerms = []
        pendingDrafts = []
        lastImportedCount = 0
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - 持久化

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(filename)
    }

    func persist() {
        do {
            struct Payload: Codable {
                let approved: [MedicalTerm]
                let pending: [CorpusImporter.Draft]
            }
            let data = try JSONEncoder().encode(Payload(approved: communityTerms, pending: pendingDrafts))
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "本机保存失败：\(error.localizedDescription)"
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            struct Payload: Codable {
                let approved: [MedicalTerm]
                let pending: [CorpusImporter.Draft]
            }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            communityTerms = payload.approved
            pendingDrafts = payload.pending
            storageError = nil
        } catch {
            storageError = "本机词库读取失败：\(error.localizedDescription)"
        }
    }
}
