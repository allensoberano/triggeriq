import HealthKit
import SwiftData

@MainActor
protocol HealthKitServiceProtocol {
    func requestAuthorization() async throws
    func fetchAndCacheDaily(for date: Date, context: ModelContext) async throws
}

@MainActor
final class HealthKitService: HealthKitServiceProtocol {
    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
        HKQuantityType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.workoutType()
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchAndCacheDaily(for date: Date, context: ModelContext) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let dayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        async let sleep = fetchSleep(start: startOfDay, end: endOfDay)
        async let hrv = fetchLatestQuantity(.heartRateVariabilitySDNN, predicate: dayPredicate, unit: .secondUnit(with: .milli))
        async let restingHR = fetchLatestQuantity(.restingHeartRate, predicate: dayPredicate, unit: .count().unitDivided(by: .minute()))
        async let steps = fetchSumQuantity(.stepCount, predicate: dayPredicate, unit: .count())
        async let workout = fetchWorkout(start: startOfDay, end: endOfDay)

        let (sleepResult, hrvValue, restingHRValue, stepCount, workoutResult) =
            try await (sleep, hrv, restingHR, steps, workout)

        let log = fetchOrCreateLog(for: startOfDay, context: context)
        log.sleepDuration = sleepResult.duration
        log.sleepQuality = sleepResult.quality
        log.avgHRV = hrvValue
        log.restingHeartRate = restingHRValue
        log.stepCount = stepCount.map { Int($0) }
        log.hadWorkout = workoutResult != nil
        log.workoutMinutes = workoutResult.map { Int($0.duration / 60) }

        try context.save()
    }

    // MARK: - Private helpers

    @MainActor
    private func fetchOrCreateLog(for startOfDay: Date, context: ModelContext) -> DailyLog {
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == startOfDay }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let log = DailyLog(date: startOfDay)
        context.insert(log)
        return log
    }

    private struct SleepResult {
        var duration: TimeInterval?
        var quality: Double?
    }

    private func fetchSleep(start: Date, end: Date) async throws -> SleepResult {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: "startDate", ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let samples = (samples as? [HKCategorySample]) ?? []

                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let deepRemValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                let asleepSamples = samples.filter { asleepValues.contains($0.value) }
                let totalDuration = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let deepRemDuration = asleepSamples.filter { deepRemValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let quality = totalDuration > 0 ? deepRemDuration / totalDuration : nil
                continuation.resume(returning: SleepResult(
                    duration: totalDuration > 0 ? totalDuration : nil,
                    quality: quality
                ))
            }
            store.execute(query)
        }
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        let sort = NSSortDescriptor(key: "startDate", ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchSumQuantity(_ identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchWorkout(start: Date, end: Date) async throws -> HKWorkout? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: "duration", ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            store.execute(query)
        }
    }
}
