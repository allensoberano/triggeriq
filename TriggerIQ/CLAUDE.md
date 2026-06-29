# TriggerIQ — Development Guidelines

## Dependency Injection

All services use **Swinject** via `AppContainer`. Never access `AppContainer.shared.container` directly at call sites — use the global `resolve()` helper:

```swift
resolve(SomeServiceProtocol.self).doSomething()
```

Each epic gets its own `Assembly` file in `DI/Assemblies/` registered in `AppContainer`. **Keep one Assembly per service/feature** — this is intentional prep for future modularization into Swift packages, where each package will own its Assembly and self-register. Don't consolidate into a single ServicesAssembly.

---

## Protocol-First Services

**Every service must be defined behind a protocol before writing the implementation.** This is non-negotiable — it keeps services injectable, mockable in tests, and swappable (e.g. the AI analysis service).

Pattern:
```swift
// 1. Define the protocol
protocol MyServiceProtocol {
    func doSomething() async throws
}

// 2. Implement it
final class MyService: MyServiceProtocol { ... }

// 3. Register in the relevant Assembly
container.register(MyServiceProtocol.self) { _ in MyService() }.inObjectScope(.container)

// 4. Resolve at call sites
resolve(MyServiceProtocol.self).doSomething()
```

### Wrapping system types (UIKit/HealthKit/UserNotifications)

System types like `UNUserNotificationCenter`, `HKHealthStore`, etc. cannot be subclassed or initialized in tests. Wrap them in a protocol so mocks can be injected:

```swift
protocol NotificationCenterProtocol {
    func notificationSettings() async -> NotificationSettingsProtocol
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProtocol { ... }
```

The real type conforms to the protocol via extension. The mock is a plain `final class` in `TriggerIQTests/Mocks/`.

**Never call system APIs directly inside a service.** Always route through the injected protocol dependency.

### SwiftData models and actors

Any protocol whose methods accept SwiftData `@Model` objects (e.g. `Meal`, `DailyLog`) must be marked `@MainActor` — SwiftData models are non-Sendable and cannot safely cross actor boundaries. Mark both the protocol and its implementation `@MainActor`:

```swift
@MainActor
protocol MyServiceProtocol {
    func doSomething(with meal: Meal) async
}

@MainActor
final class MyService: MyServiceProtocol { ... }
```

---

## Testing

- One test file per service: `<ServiceName>Tests.swift` in `TriggerIQTests/`
- Mocks live in `TriggerIQTests/Mocks/` and are shared across test files
- Use Swift Testing (`@Test`, `#expect`) — not XCTest
- For SwiftData in tests: declare `container: ModelContainer` and `context: ModelContext` as stored properties on the test struct — Swift Testing recreates the struct before each `@Test`, giving each test a fresh isolated store automatically
- For HealthKit: use `MockHealthKitService` (the real store is unavailable in tests)

---

## Architecture Notes

- **SwiftData** for all persistence (iOS 17+). No CloudKit in V1.
- **AI service** (`AnalysisServiceProtocol`) must remain a swappable protocol — the backing model is not decided.
- `SuspectFoodPattern` is engine output only — never written by user input.
- `CheckIn.skipped = true` is not the same as unanswered. Never treat a missing check-in as zero severity.
