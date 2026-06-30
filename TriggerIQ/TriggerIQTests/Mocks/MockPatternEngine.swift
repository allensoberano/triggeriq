import Foundation
import SwiftData
@testable import TriggerIQ

final class MockPatternEngine: PatternEngineProtocol {
    var recomputeCalled = false

    func recompute(context: ModelContext) {
        recomputeCalled = true
    }
}
