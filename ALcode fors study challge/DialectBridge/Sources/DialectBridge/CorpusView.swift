import SwiftUI
import UIKit

/// 词库共建页：把"我不会编程但我知道本地人怎么说话"变成一次可审核的贡献。
struct CorpusView: View {
    @ObservedObject var store: TerminologyStore
    var onImported: () -> Void = {}
    @State private var input = """
    # 规范医学词 | 方言说法（逗号分隔） | 大类 | 片区
    胸闷 | 心口闷，压得慌，胸口堵 | 心肺 | 吴语
    头晕 | 晕乎乎，天旋地转 | 神经 | 西南官话
    """
    @State private var drafts: [CorpusImporter.Draft] = []
    @State private var errorMessage: String?
    @State private var imported = 0

    var body: some View {
        List {
            Section("粘贴语料（一行一条）") {
                TextEditor(text: $input)
                    .font(.system(size: 17, design: .monospaced))
                    .frame(minHeight: 160)
            }

            Section {
                Button("解析并预览") { parse() }
                Button("导出当前词库") {
                    UIPasteboard.general.string = CorpusImporter.export()
                }
                .buttonStyle(.bordered)
            }

            if let errorMessage {
                Section("有问题") {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            if !drafts.isEmpty {
                Section("待审核（\(drafts.count) 条）") {
                    ForEach(drafts) { draft in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.standard).font(.headline)
                            Text(draft.colloquialisms.joined(separator: "、"))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("\(draft.category.rawValue) · \(draft.regions.isEmpty ? "通用" : draft.regions.map(\.rawValue).joined(separator: "、"))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Text("共提交 \(imported) 条。每一条都需要社区医生签字后才会进入正式词库——作品宁可慢，也不让未经核对的说法污染分诊。")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if !store.pendingDrafts.isEmpty {
                Section("待复核（\(store.pendingDrafts.count) 条，签字后才生效）") {
                    ForEach(store.pendingDrafts) { draft in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.standard).font(.headline)
                            Text(draft.colloquialisms.joined(separator: "、"))
                                .font(.subheadline).foregroundStyle(.secondary)
                            HStack {
                                Button("医生签字通过") {
                                    store.approve(draft)
                                    onImported()
                                }
                                .buttonStyle(.borderedProminent)
                                Button("驳回") {
                                    store.reject(draft)
                                    onImported()
                                }
                                .buttonStyle(.bordered)
                            }
                            .font(.footnote)
                        }
                    }
                    Button("全部通过") {
                        store.approveAll()
                        onImported()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = store.storageError {
                Section("存储异常") {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("本机共建词库（\(store.communityTerms.count) 条已签字，不上传）") {
                if store.communityTerms.isEmpty {
                    Text("还没有共建条目").foregroundStyle(.secondary)
                }
                ForEach(store.communityTerms) { term in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(term.standard).font(.headline)
                            Text(term.colloquialisms.joined(separator: "、"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.removeCommunityTerm(id: term.id)
                            onImported()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("删除 \(term.standard)")
                    }
                }
            }
        }
        .navigationTitle("共建词库")
    }

    private func parse() {
        do {
            let result = try CorpusImporter.parse(input)
            drafts = result
            imported += store.importDrafts(result)
            onImported()
            errorMessage = nil
        } catch {
            drafts = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
