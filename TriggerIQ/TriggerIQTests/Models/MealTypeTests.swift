import Testing
import Foundation
@testable import TriggerIQ

struct MealTypeTests {

    private func date(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    @Test func earlyMorningIsBreakfast() {
        #expect(MealType.suggested(for: date(hour: 5)) == .breakfast)
    }

    @Test func midMorningIsBreakfast() {
        #expect(MealType.suggested(for: date(hour: 9)) == .breakfast)
    }

    @Test func elevenAmIsLunch() {
        #expect(MealType.suggested(for: date(hour: 11)) == .lunch)
    }

    @Test func onePmIsLunch() {
        #expect(MealType.suggested(for: date(hour: 13)) == .lunch)
    }

    @Test func threepmIsSnack() {
        #expect(MealType.suggested(for: date(hour: 15)) == .snack)
    }

    @Test func sixPmIsDinner() {
        #expect(MealType.suggested(for: date(hour: 18)) == .dinner)
    }

    @Test func eightPmIsDinner() {
        #expect(MealType.suggested(for: date(hour: 20)) == .dinner)
    }

    @Test func lateNightIsSnack() {
        #expect(MealType.suggested(for: date(hour: 22)) == .snack)
    }

    @Test func midnightIsSnack() {
        #expect(MealType.suggested(for: date(hour: 0)) == .snack)
    }
}
