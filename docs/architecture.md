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
    C --> D[@Published pendingCheckIn\non NotificationDelegate]
    D --> E[TriggerIQApp\npresents CheckInView sheet]
    E --> F{User action}
    F -->|Rate symptoms| G[CheckInViewModel.save]
    F -->|Skip| H[CheckInViewModel.skip\nskipped=true, no symptom data]
    F -->|Log bowel/hydration| I[BristolHydrationView sheet]
    I --> J[Insert BowelMovementEntry\nor HydrationEntry to DailyLog]
    G --> K[Insert CheckIn\ncompletedTime = now]
    K --> L[voidSupersededCheckIns\ncreate skipped records for earlier types]
    L --> M[cancelCheckIns for meal\nremove pending OS notifications]
    M --> N([Sheet dismisses\nToday banner clears])
    H --> N
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

## Epic 7 — Insights Screen

```mermaid
flowchart TD
    A([Insights Tab]) --> B[InsightsView]
    B --> C[InsightsViewModel.load]
    C --> D[Fetch all Meals\nsorted chronologically]
    C --> E[Fetch SuspectFoodPatterns\nsorted by avgSymptomSeverity desc]
    D --> F[ScorePoint array\ndate + predictedScore + mealType]
    F --> G0[rollingAveraged\ntrailing 5-point window]
    G0 --> G[ScoreTrendChart\nSwift Charts line + scatter\nbaseline rule mark]
    E --> H{patterns empty?}
    H -->|yes| I[PatternsInsufficientDataView]
    H -->|no| J[FoodPatternRow list\ntop 10 patterns]
    J --> K[Severity bar vs baseline\nconfidence badge\nsampleSize label]

    B --> L[Refresh toolbar button]
    L --> M[InsightsViewModel\nrecomputePatterns]
    M --> N[PatternEngine.recompute\nTask.detached userInitiated]
    N --> O[Group completed check-ins\nby canonicalTag]
    O --> P[Upsert SuspectFoodPattern rows\navgSymptomSeverity\nbaselineSeverity\nconfidence]
    P --> Q[context.save]
    Q --> R[reload on MainActor]
```

---

## Epic 7 — Pattern Engine Logic

```mermaid
flowchart TD
    A([PatternEngine.recompute]) --> B[Fetch all Meals + CheckIns]
    B --> C[Filter: completedTime != nil\nand skipped == false]
    C --> D[Compute baseline\navg maxSeverity across all check-ins]
    D --> E[For each Meal\nfind matching completed check-ins]
    E --> F[Avg maxSeverity per meal]
    F --> G[Group by canonicalTag\nbuild tagSeverities dict]
    G --> H[Upsert SuspectFoodPattern\nper canonical tag]
    H --> I{sampleSize}
    I -->|<5| J[confidence: low]
    I -->|5–9| K[confidence: emerging]
    I -->|10+| L[confidence: strong]
    G --> M[Delete patterns\nfor tags no longer present]
```

---

## DI — Assembly & Resolution (Epic 7)

```mermaid
flowchart LR
    AC[AppContainer\nAssembler] --> PE[PatternEngine\nAssembly]
    PE --> PEP[PatternEngine\nPatternEngineProtocol]
    IV[InsightsViewModel] --> PEP
```

---

## Epic 8 — Onboarding & Settings

```mermaid
flowchart TD
    A([App Launch]) --> B[RootView\nfetch UserProfile]
    B --> C{onboardingCompleted?}
    C -->|false / missing| D[OnboardingView\nTabView page flow]
    C -->|true| E[ContentView\n4-tab shell]

    D --> D1[Page 0: Welcome]
    D1 --> D2[Page 1: Conditions & Allergies\nfree text → knownConditions/knownAllergies]
    D2 --> D3[Page 2: Notifications\nrequest permission]
    D3 --> D4[Page 3: HealthKit\nrequest authorization]
    D4 --> D5[Page 4: Ready\nGet Started → onboardingCompleted = true]
    D5 --> B

    E --> T1[Today tab]
    E --> T2[History tab]
    E --> T3[Insights tab]
    E --> T4[Settings tab]

    T4 --> S[SettingsView]
    S --> S1[Edit conditions / allergies]
    S --> S2[Toggle 1-hr / 3-hr / morning check-ins]
    S --> S3[Clear All Data\ndeletes meals + photos + patterns + logs]
```

---

## Epic 8 — Meal Type Preselection

```mermaid
flowchart TD
    A([Log Meal tapped]) --> B[LogMealViewModel init]
    B --> C[MealType.suggested for: Date]
    C --> D{hour of day}
    D -->|5–10| E[breakfast]
    D -->|11–14| F[lunch]
    D -->|15–17| G[snack]
    D -->|18–20| H[dinner]
    D -->|21–4| I[snack]
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
