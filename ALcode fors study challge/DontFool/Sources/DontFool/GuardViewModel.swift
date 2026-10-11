import Foundation
import SwiftUI

@MainActor
final class GuardViewModel: ObservableObject {
    @Published private(set) var history: [FraudAssessment] = []
    @Published private(set) var current: FraudAssessment?

    let guardEngine = LiveGuard()
    private var window = LiveGuard.RollingWindow()

    /// 喂进来一句话，返回当前累计判断
    @discardableResult
    func ingest(_ utterance: String) -> FraudAssessment {
        window.push(utterance)
        let assessment = guardEngine.assess(window.text)
        current = assessment
        if assessment.level >= .alerting {
            history.insert(assessment, at: 0)
            if history.count > 10 { history.removeLast() }
        }
        return assessment
    }

    func replay(_ lines: [String]) {
        window = LiveGuard.RollingWindow()
        history = []
        current = nil
        for line in lines {
            _ = ingest(line)
        }
    }

    func reset() {
        window = LiveGuard.RollingWindow()
        history = []
        current = nil
    }
}
