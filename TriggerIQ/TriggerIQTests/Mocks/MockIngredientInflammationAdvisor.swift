@testable import TriggerIQ

final class MockIngredientInflammationAdvisor: IngredientInflammationAdvisorProtocol {
    var stubbedAdvice: IngredientInflammationAdvice = .init(level: .low, replacementTip: nil)
    var receivedTags: [ParsedFoodTag] = []

    func advice(for tag: ParsedFoodTag) -> IngredientInflammationAdvice {
        receivedTags.append(tag)
        return stubbedAdvice
    }
}
