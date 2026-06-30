# TriggerIQ — Architecture Diagrams

## App Startup — Permission Flow

```mermaid
flowchart TD
    A([App Launch]) --> B[TriggerIQApp.task]
    B --> C[NotificationPermissionManager\nrequestPermissionIfNeeded]
    B --> D[HealthKitService\nrequestAuthorization]
    C --> E{UNAuth\nStatus?}
    E -->|notDetermined| F[Show system\nnotification prompt]
    E -->|authorized\ndenied| G[Skip]
    D --> H{HealthKit\navailable?}
    H -->|yes| I[Request read\npermissions]
    H -->|no| J[Skip]
```

---

## Meal Saved — Notification Scheduling Flow

```mermaid
flowchart TD
    A([Meal Saved]) --> B[NotificationSchedulingService\nscheduleCheckIns]
    B --> C{Notifications\nauthorized?}
    C -->|no| D([Done])
    C -->|yes| E[Schedule +1hr\ncheck-in notification]
    E --> F[Schedule +4hr\ncheck-in notification]
    F --> G[scheduleNextMorningSummary\n8am next day]
    G --> H([Done])
    A --> I[Meal deleted?]
    I -->|yes| J[cancelCheckIns\nremove pending by meal ID]
```

---

## DI — Assembly & Resolution

```mermaid
flowchart LR
    AC[AppContainer\nAssembler] --> NA[NotificationService\nAssembly]
    AC --> HA[HealthKitService\nAssembly]
    NA --> NCP[NotificationCenter\nProtocol]
    NA --> NPM[NotificationPermission\nManager]
    NA --> NSS[NotificationScheduling\nService]
    HA --> HKS[HealthKitService\nProtocol]
    R([resolve&lt;T&gt;]) --> AC
```

---

## HealthKit Daily Cache Flow

```mermaid
flowchart TD
    A([fetchAndCacheDaily\ndate + ModelContext]) --> B{DailyLog\nexists for date?}
    B -->|yes| C[Update existing]
    B -->|no| D[Create new DailyLog]
    C --> E
    D --> E[Fetch in parallel]
    E --> F[Sleep duration\n+ quality %]
    E --> G[HRV\nresting HR]
    E --> H[Step count]
    E --> I[Workout\nduration]
    F & G & H & I --> J[Write to DailyLog]
    J --> K[context.save]
```

---

## Epic 4 — Check-in Flow

```mermaid
flowchart TD
    A([Notification tap]) --> B[NotificationDelegate\ndidReceive response]
    B --> C[Parse identifier\ntype + mealID]
    C --> D[Post openCheckIn\nNotification]
    D --> E[TriggerIQApp\npresents CheckInView sheet]
    E --> F{User action}
    F -->|Rate symptoms| G[CheckInViewModel.save\ninserts CheckIn to SwiftData]
    F -->|Skip| H[CheckInViewModel.skip\nskipped=true, no symptom data]
    F -->|Log bowel/hydration| I[BristolHydrationView sheet]
    I --> J[Insert BowelMovementEntry\nor HydrationEntry to DailyLog]
    G --> K([Sheet dismisses])
    H --> K
```

---

## Epic 3 — Meal Logging Flow

```mermaid
flowchart TD
    A([Log Meal button]) --> B[LogMealSheet]
    B --> C{Input method}
    C -->|photo| D[PhotosPicker\nload image data]
    C -->|text| E[Manual text entry]
    D --> F[AnalysisService\nanalyze imageData]
    E --> G[AnalysisService\nanalyze text]
    F --> H[AnalysisResult]
    G --> H
    H --> I[MealConfirmView\nreview + edit]
    I -->|Save| J[Create Meal + FoodTags\ninsert into ModelContext]
    J --> K[NotificationSchedulingService\nscheduleCheckIns]
    K --> L[Sheet dismisses]
    I -->|Edit| B
```

---

## DI — Assembly & Resolution (Epic 3)

```mermaid
flowchart LR
    AC[AppContainer\nAssembler] --> NA[NotificationService\nAssembly]
    AC --> HA[HealthKitService\nAssembly]
    AC --> AA[AnalysisService\nAssembly]
    NA --> NCP[NotificationCenter\nProtocol]
    NA --> NPM[NotificationPermission\nManager]
    NA --> NSS[NotificationScheduling\nService]
    HA --> HKS[HealthKitService\nProtocol]
    AA --> AS[AnalysisService\nProtocol → StubAnalysisService]
    R([resolve&lt;T&gt;]) --> AC
```


---

## Epic 5 — Today Screen

```mermaid
flowchart TD
    A([App Launch]) --> B[TodayView]
    B --> C[TodayViewModel.load]
    C --> D[Fetch today's Meals]
    C --> E{DailyLog\nexists?}
    E -->|yes| F[Load confounders\nstress / alcohol / caffeine]
    E -->|no| G[Create DailyLog\nfor today]
    B --> H[TodayViewModel.refreshHealthKit]
    H --> I[HealthKitService\nfetchAndCacheDaily]
    I --> J[Update DailyLog\ncached metrics]

    B --> K{hasPendingCheckIn?}
    K -->|yes| L[Pending check-in card\nshows in list]
    L --> M[Tap → CheckInView sheet\nwith correct type + mealID]
    K -->|no| N[No card shown]

    B --> O[Confounder +/- controls]
    O --> P[onChange → saveConfounders\npersists to DailyLog]

    B --> Q[Log Meal + button]
    Q --> R[LogMealSheet]
    R --> S[On dismiss → reload]
```

---

## Epic 7a — AI Analysis (Claude API)

```mermaid
flowchart TD
    A([Meal input]) --> B{Input type}
    B -->|Camera| C[CameraView\nUIImagePickerController]
    B -->|Library| D[PhotosPicker\nloadTransferable]
    B -->|Text| E[Manual text entry]

    C --> F[Convert HEIC → JPEG\n0.8 compression]
    D --> F
    F --> G[LiveAnalysisService\nanalyze imageData]
    E --> H[LiveAnalysisService\nanalyze text]

    G --> I[AnthropicClient\nPOST /v1/messages\nClaude Haiku]
    H --> I
    I --> J{API key?}
    J -->|Keychain| K[LiveAnalysisService]
    J -->|Secrets.plist| K
    J -->|missing| L[StubAnalysisService\nfallback]

    K --> M[Strip markdown fences\nparse JSON response]
    M --> N[AnalysisResult\ndescription + score + tags]
    L --> N

    N --> O[MealConfirmView]
    O -->|Save| P[PhotoStorageService\nsave JPEG to app sandbox]
    P --> Q[meal.photoFileName set\nphotoExpiryDate = +14 days]
    Q --> R[Meal inserted to SwiftData]

    S([App launch]) --> T[ContentView.task\npurgeExpired]
    T --> U{meal.photoExpiryDate\n<= now?}
    U -->|yes| V[Delete file from sandbox\nphotoDeleted = true\nphotoFileName = nil]
    U -->|no| W[Keep photo]
```

---

## Epic 7a — DI Assembly

```mermaid
flowchart LR
    AC[AppContainer\nAssembler] --> AA[AnalysisService\nAssembly]
    AC --> PA[PhotoStorage\nAssembly]
    AA --> LA[LiveAnalysisService\nif API key present]
    AA --> SA[StubAnalysisService\nfallback]
    LA --> AC2[AnthropicClient\nURLSession]
    PA --> PS[PhotoStorageService\napp sandbox]
```

---

## Epic 6 — History & Meal Detail

```mermaid
flowchart TD
    A([History Tab]) --> B[HistoryView]
    B --> C[FetchDescriptor\nMeal sorted by timestamp desc]
    C --> D{meals empty?}
    D -->|yes| E[ContentUnavailableView]
    D -->|no| F[Group by startOfDay\nDictionary grouping]
    F --> G[List sections\nformatted date headers]
    G --> H[NavigationLink → MealDetailView]

    H --> I[MealDetailView]
    I --> J[MealHeaderView\nphoto placeholder + time/type]
    I --> K[ScoreBarView\npredictedScore progress bar]
    I --> L[FlowLayout\nfood tag chips]
    I --> M[CheckInTimeline\noneHour + fourHour rows]
    M --> N{checkIn state}
    N -->|completed| O[symptom summary + color dot]
    N -->|skipped| P[Skipped label]
    N -->|no response| Q[No response label]
    I --> R[loadDailyLog\nfetch DailyLog for meal day]
    R --> S[ConfounderSummaryView\nstress / alcohol / caffeine chips]
```
