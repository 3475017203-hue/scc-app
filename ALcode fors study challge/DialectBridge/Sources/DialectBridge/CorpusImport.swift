import Foundation

/// 词库共建导入器。
/// 作品的瓶颈不是算法而是**语料**——医生和方言志愿者最懂"本地人怎么说病"。
/// 这个解析器让他们把一句话直接粘进来，自动生成可审核的术语条目。
struct CorpusImporter {
    struct Draft: Identifiable, Hashable, Codable {
        let id = UUID()
        let standard: String
        let colloquialisms: [String]
        let category: SymptomCategory
        let regions: [DialectRegion]

        var term: MedicalTerm {
            MedicalTerm(id, standard, colloquialisms: colloquialisms,
                        note: "社区共建条目，请医生复核补充问诊要点。",
                        category: category, regions: regions)
        }
    }

    enum ParseError: LocalizedError {
        case emptyInput, missingStandard, missingColloquialism, tooManyColloquialisms

        var errorDescription: String? {
            switch self {
            case .emptyInput: "还没有内容"
            case .missingStandard: "缺少规范医学词"
            case .missingColloquialism: "至少要写一条方言说法"
            case .tooManyColloquialisms: "方言说法最多 8 条"
            }
        }
    }

    /// 输入格式（一行一条，用 | 分隔）：
    ///   规范医学词 | 方言说法1,方言说法2 | 大类 | 片区
    /// 例：
    ///   胸闷 | 心口闷,压得慌,胸口堵 | 心肺 | 吴语
    ///   头晕 | 晕乎乎,天旋地转 | 神经 | 西南官话
    static func parse(_ raw: String) throws -> [Draft] {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard !lines.isEmpty else { throw ParseError.emptyInput }

        var drafts: [Draft] = []
        for line in lines {
            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let standard = parts.first, !standard.isEmpty else { throw ParseError.missingStandard }

            let colloquialisms = parts.count > 1
                ? parts[1].components(separatedBy: CharacterSet(charactersIn: "，,、")).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }.filter { !$0.isEmpty }
                : []
            guard !colloquialisms.isEmpty else { throw ParseError.missingColloquialism }
            guard colloquialisms.count <= 8 else { throw ParseError.tooManyColloquialisms }

            let category = parts.count > 2
                ? SymptomCategory.allCases.first { $0.rawValue.contains(parts[2]) } ?? .general
                : .general
            let regions = parts.count > 3
                ? DialectRegion.allCases.filter { parts[3].contains($0.rawValue.prefix(2)) }
                : []

            drafts.append(Draft(standard: standard, colloquialisms: colloquialisms,
                                category: category, regions: regions))
        }
        return drafts
    }

    /// 导出当前词库，方便社区志愿者在表格里改完再导回来。
    static func export(_ terms: [MedicalTerm] = Terminology.all) -> String {
        var lines = ["# 规范医学词 | 方言说法（逗号分隔）| 大类 | 片区"]
        for term in terms {
            let regions = term.regions.isEmpty ? "通用" : term.regions.map(\.rawValue).joined(separator: "、")
            lines.append("\(term.standard) | \(term.colloquialisms.joined(separator: "，")) | \(term.category.rawValue) | \(regions)")
        }
        return lines.joined(separator: "\n")
    }
}
