//
//  TriggerIQApp.swift
//  TriggerIQ
//
//  Created by Allen Soberano on 6/28/26.
//

import SwiftUI
import SwiftData

@main
struct TriggerIQApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            FoodTag.self,
            CheckIn.self,
            DailyLog.self,
            BowelMovementEntry.self,
            HydrationEntry.self,
            UserProfile.self,
            SuspectFoodPattern.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await resolve(NotificationPermissionManager.self).requestPermissionIfNeeded()
                    try? await resolve(HealthKitServiceProtocol.self).requestAuthorization()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
