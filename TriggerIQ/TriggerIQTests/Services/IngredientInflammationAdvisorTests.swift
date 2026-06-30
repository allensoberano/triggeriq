import Testing
@testable import TriggerIQ

struct IngredientInflammationAdvisorTests {
    let advisor = IngredientInflammationAdvisor()

    @Test func highInflammationTagHasReplacementTip() {
        let tag = ParsedFoodTag(rawName: "Bacon", canonicalTag: "processed meat", category: "protein")

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .high)
        #expect(advice.replacementTip != nil)
    }

    @Test func moderateInflammationTagHasReplacementTip() {
        let tag = ParsedFoodTag(rawName: "Cheese", canonicalTag: "dairy", category: "dairy")

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .moderate)
        #expect(advice.replacementTip != nil)
    }

    @Test func lowInflammationTagHasNoReplacementTip() {
        let tag = ParsedFoodTag(rawName: "Spinach", canonicalTag: "leafy greens", category: "vegetable")

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .low)
        #expect(advice.replacementTip == nil)
    }

    @Test func matchesByCanonicalTagWhenRawNameDiffers() {
        // rawName is the user-facing label ("Soda"); canonicalTag carries the matchable keyword
        let tag = ParsedFoodTag(rawName: "Soda", canonicalTag: "sugary drink", category: nil)

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .high)
    }

    @Test func matchesByCategoryWhenNameAndTagDontMatch() {
        let tag = ParsedFoodTag(rawName: "Mystery Item", canonicalTag: "unknown", category: "fried")

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .high)
    }

    @Test func matchIsCaseInsensitive() {
        let tag = ParsedFoodTag(rawName: "BACON STRIPS", canonicalTag: "PROCESSED MEAT", category: nil)

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .high)
    }

    @Test func unmatchedIngredientDefaultsToLowWithNoTip() {
        let tag = ParsedFoodTag(rawName: "Quinoa Bowl", canonicalTag: "grain bowl", category: "grain")

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .low)
        #expect(advice.replacementTip == nil)
    }

    @Test func highSeverityRuleTakesPrecedenceOverModerate() {
        // "beef" alone is moderate, but "processed meat" rule (high) should win when both could match
        let tag = ParsedFoodTag(rawName: "Beef Sausage", canonicalTag: "processed meat", category: "protein")

        let advice = advisor.advice(for: tag)

        #expect(advice.level == .high)
    }
}
