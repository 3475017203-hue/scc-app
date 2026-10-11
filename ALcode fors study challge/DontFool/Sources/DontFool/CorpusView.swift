import SwiftUI

/// 社区共建页：让被骗过的老人用自己的话，为后面的人挡住一次。
struct CorpusView: View {
    @StateObject private var corpus = ScamCorpus()
    @State private var transcript = ""
    @State private var experience = ""
    @State private var role = ""
    @State private var byline = ""
    @State private var extracted: [String] = []

    var body: some View {
        List {
            Section("把骗子说过的话写下来") {
                TextField("骗子的原话（越原越好）", text: $transcript, axis: .vertical)
                    .lineLimit(3...8)
                TextField("他说他是谁", text: $role)
                TextField("后来发生了什么", text: $experience, axis: .vertical)
                    .lineLimit(2...6)
                TextField("可以署名，也可以不写", text: $byline)
                Button("提交给社区审核") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(transcript.isEmpty)
            }

            if !extracted.isEmpty {
                Section("从这段话里抽出的关键词") {
                    Text(extracted.joined(separator: "、")).font(.footnote)
                }
            }

            if !corpus.pending.isEmpty {
                Section("待签字（\(corpus.pending.count) 条）") {
                    ForEach(corpus.pending) { story in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(story.transcript).font(.footnote)
                            HStack {
                                Button("民警签字") { _ = corpus.approve(story, by: "社区民警") }
                                    .buttonStyle(.borderedProminent)
                                Button("驳回") { corpus.reject(story) }
                                    .buttonStyle(.bordered)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }

            Section("已入库的真实经历（\(corpus.approved.count) 条）") {
                ForEach(corpus.approved) { story in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.claimedRole.isEmpty ? "真实经历" : story.claimedRole).font(.headline)
                        Text(story.experience).font(.footnote).foregroundStyle(.secondary)
                        if !story.byline.isEmpty {
                            Text("—— " + story.byline).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Text("这套词库永远留在本机，不上传。签字的人必须是社区民警、反诈人员或社区工作者——因为下一位要靠它做判断的人，可能是你家的孩子。")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if let error = corpus.storageError {
                Section("提示") { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("共建话术库")
        .onAppear { corpus.load() }
    }

    private func submit() {
        let story = ScamStory(transcript: transcript, experience: experience, claimedRole: role, byline: byline)
        extracted = corpus.extractTriggers(from: story)
        corpus.submit(story)
        transcript = ""
        experience = ""
        role = ""
        byline = ""
    }
}
