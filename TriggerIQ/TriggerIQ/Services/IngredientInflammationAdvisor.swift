import Foundation

enum IngredientInflammationLevel {
    case low
    case moderate
    case high
}

struct IngredientInflammationAdvice {
    let level: IngredientInflammationLevel
    let replacementTip: String?
}

protocol IngredientInflammationAdvisorProtocol {
    func advice(for tag: ParsedFoodTag) -> IngredientInflammationAdvice
}

final class IngredientInflammationAdvisor: IngredientInflammationAdvisorProtocol {
    private struct Rule {
        let keywords: [String]
        let level: IngredientInflammationLevel
        let replacementTip: String?
    }

    private static let rules: [Rule] = [
        Rule(
            keywords: ["soda", "soft drink", "sugary drink", "energy drink"],
            level: .high,
            replacementTip: "Try sparkling water with lemon or unsweetened iced tea."
        ),
        Rule(
            keywords: ["bacon", "sausage", "hot dog", "pepperoni", "processed meat"],
            level: .high,
            replacementTip: "Try grilled chicken, salmon, or lentils instead of processed meat."
        ),
        Rule(
            keywords: ["deep fried", "fried", "french fries"],
            level: .high,
            replacementTip: "Try baked, roasted, or air-fried options with olive oil."
        ),
        Rule(
            keywords: ["candy", "dessert", "added sugar", "syrup"],
            level: .high,
            replacementTip: "Try fresh fruit with nuts or plain yogurt with cinnamon."
        ),
        Rule(
            keywords: ["white bread", "refined grain", "pastry"],
            level: .high,
            replacementTip: "Try whole-grain bread or oats to reduce inflammatory load."
        ),
        Rule(
            keywords: ["beef", "pork", "red meat"],
            level: .moderate,
            replacementTip: "Try fish, chicken, tofu, or beans more often."
        ),
        Rule(
            keywords: ["dairy", "cheese", "cream", "ice cream"],
            level: .moderate,
            replacementTip: "Try unsweetened yogurt alternatives or avocado-based sauces."
        ),
        Rule(
            keywords: ["butter"],
            level: .moderate,
            replacementTip: "Try extra-virgin olive oil in place of butter when possible."
        ),
        Rule(
            keywords: ["white rice", "white pasta", "pasta"],
            level: .moderate,
            replacementTip: "Try brown rice, quinoa, or legume-based pasta."
        ),
        Rule(
            keywords: ["gluten"],
            level: .moderate,
            replacementTip: "If gluten is a trigger for you, try quinoa, rice, or potatoes."
        )
    ]

    func advice(for tag: ParsedFoodTag) -> IngredientInflammationAdvice {
        let haystacks = [
            tag.rawName.lowercased(),
            tag.canonicalTag.lowercased(),
            (tag.category ?? "").lowercased()
        ]

        if let match = IngredientInflammationAdvisor.rules.first(where: { rule in
            rule.keywords.contains(where: { keyword in
                haystacks.contains(where: { $0.contains(keyword) })
            })
        }) {
            return IngredientInflammationAdvice(level: match.level, replacementTip: match.replacementTip)
        }

        return IngredientInflammationAdvice(level: .low, replacementTip: nil)
    }
}
