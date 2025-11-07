## SunnyPet · AntiEmoPet

Weather-driven daily quests + virtual pet companion. MVP implements the closed loop described in `PRD/SunnyPet_iOS_TechSpec_MVP.md`: (任务 → 奖励 → 宠物反馈 → 商店消费) with SwiftUI + SwiftData + MVVM.

### Quick Start
1. Requirements: Xcode 15.4+, iOS 17 simulator/device, SwiftData enabled.
2. Open `AntiEmoPet.xcodeproj`.
3. Run target **AntiEmoPet** on an iOS 17 simulator.
4. 首次启动按照 Onboarding 输入昵称与地区，并授权通知（可选）。

### Architecture

| Layer | Path | Notes |
| --- | --- | --- |
| App | `AntiEmoPet/App/SunnyPetApp.swift` | Creates `ModelContainer` for Task / TaskTemplate / Pet / Item / UserStats and launches `ContentView`. |
| Core Models | `AntiEmoPet/Core/Models` | SwiftData `@Model` classes that mirror PRD fields (`Task`, `Pet`, `Item`, `UserStats`, `TaskTemplate`) plus lightweight helper structs (`ChatMessage`). |
| Core Services | `AntiEmoPet/Core/Services` | Business logic modules: storage bootstrapping, task generation, rewards, pet engine, notifications, weather, chat placeholder, analytics logger. |
| App State | `AntiEmoPet/Core/App/AppViewModel.swift` | Single source of truth that coordinates services and exposes observable state to feature modules. |
| Features | `AntiEmoPet/Features/<Module>` | Each screen has its own View + ViewModel (Home, Tasks, Pet, Shop, Profile, Chat, Onboarding). |
| UI Components | `AntiEmoPet/UIComponents` | Shared visual atoms such as `DashboardCard` & `PrimaryButton`. |

### Feature Checklist
- **Onboarding** (`Features/Onboarding`) – completes nickname/region setup, optional notification opt-in. Tied to `UserStats` persistence.
- **Home** (`Features/Home`) – weather summary, progress, quick pet actions.
- **Tasks** (`Features/Tasks`) – toggles daily quests with reward + streak logic (`RewardEngine`).
- **Pet** (`Features/Pet`) – shows mood/hunger/level, pat & snack shortcuts via `PetEngine`.
- **Shop** (`Features/Shop`) – grouped catalog, purchase validation, energy deduction.
- **Profile** (`Features/Profile`) – streak/energy overview & notification toggle sync.
- **Chat** (`Features/Chat`) – placeholder Sunny dialog that responds deterministically based on weather + mood.

### Services Snapshot
- `StorageService` bootstraps default templates/pet/stats/items and wraps SwiftData CRUD.
- `TaskGeneratorService` derives 3–6 tasks/day per weather template.
- `RewardEngine` handles +10 energy baseline (difficulty scaled) + streak increments + purchase deductions.
- `PetEngine` syncs mood/hunger/xp progression after tasks/interactions.
- `NotificationService` requests permission + schedules 8:00 & 20:30 reminders.
- `WeatherService` randomizes weather type for MVP.
- `ChatService` returns deterministic replies; swap with real AI later.
- `AnalyticsService` logs core events via `os.Logger`.

### Extending the MVP
1. Replace `WeatherService` with WeatherKit and attach location from Onboarding region.
2. Expand `TaskTemplate` dataset per locale/weather combos and sync from remote config.
3. Introduce SwiftData relationships (e.g., `UserStats` ↔️ `Task`) for richer analytics.
4. Hook `ChatService` into OpenAI/Vertex APIs; stream results to `ChatView`.
5. Build `NotificationService` fallback UI when permission denied.

### Branch & Commit Workflow
Create a topic branch before committing:

```bash
git checkout -b feature/mvp-bootstrap
git add .
git commit -m "feat: build SunnyPet MVP loop"
```

Then open a PR back to `main`. The repo currently has `.DS_Store` noise—avoid reverting user changes you didn’t author.
