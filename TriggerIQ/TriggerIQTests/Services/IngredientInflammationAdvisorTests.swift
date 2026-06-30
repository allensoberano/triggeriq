import Testing
@testable import TriggerIQ

struct IngredientInflammationAdvisorTests {
    @Test func highInflammationTagHasReplacementTip() {
        let tag = ParsedFoodTag(rawName: "Bacon", canonicalTag: "processed meat", category: "protein")

        let advice = IngredientInflammationAdvisor.advice(for: tag)

        #expect(advice.level == .high)
        #expect(advice.replacementTip != nil)
    }

    @Test func moderateInflammationTagHasReplacementTip() {
        let tag = ParsedFoodTag(rawName: "Cheese", canonicalTag: "dairy", category: "dairy")

        let advice = IngredientInflammationAdvisor.advice(for: tag)

        #expect(advice.level == .moderate)
        #expect(advice.replacementTip != nil)
    }

    @Test func lowInflammationTagHasNoReplacementTip() {
        let tag = ParsedFoodTag(rawName: "Spinach", canonicalTag: "leafy greens", category: "vegetable")

        let advice = IngredientInflammationAdvisor.advice(for: tag)

        #expect(advice.level == .low)
        #expect(advice.replacementTip == nil)
    }
}
