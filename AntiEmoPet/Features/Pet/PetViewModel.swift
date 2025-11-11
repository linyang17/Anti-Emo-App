import Foundation

@MainActor
final class PetViewModel: ObservableObject {
    enum TimeOfDay: String, CaseIterable {
        case day
        case night
    }

    struct ScreenState: Equatable {
        var backgroundAsset: String
        var petAsset: String
        var weatherDescription: String
        var weather: WeatherType
        var timeOfDay: TimeOfDay
    }

    struct StatusSummary: Equatable {
        var energy: Int
        var bond: Int
        var levelLabel: String
        var experienceProgress: Double
    }

    @Published private(set) var screenState: ScreenState
    @Published private(set) var statusSummary: StatusSummary

    init() {
        screenState = ScreenState(
            backgroundAsset: "bg-main",
            petAsset: "foxcurious",
            weatherDescription: "",
            weather: .sunny,
            timeOfDay: .day
        )
        statusSummary = StatusSummary(
            energy: 0,
            bond: 30,
            levelLabel: "LV.1 · 0/10",
            experienceProgress: 0
        )
    }

    func sync(with appModel: AppViewModel) {
        updateStatus(stats: appModel.userStats, pet: appModel.pet)
        updatePetState(pet: appModel.pet)
        updateScene(weather: appModel.weather, timeOfDay: screenState.timeOfDay)
    }

    func updateStatus(stats: UserStats?, pet: Pet?) {
        var summary = statusSummary
        summary.energy = stats?.totalEnergy ?? 0

        if let pet {
            summary.bond = bondValue(for: pet.mood)
            let requirement = xpRequirement(for: pet.level)
            let clampedRequirement = max(requirement, 1)
            let progress = Double(max(0, min(pet.xp, clampedRequirement))) / Double(clampedRequirement)
            summary.experienceProgress = min(max(progress, 0), 1)
            summary.levelLabel = "LV.\(pet.level) · \(min(pet.xp, clampedRequirement))/\(clampedRequirement)"
        } else {
            summary.bond = 30
            summary.experienceProgress = 0
            summary.levelLabel = "尚未创建宠物"
        }

        statusSummary = summary
    }

    func updateScene(weather: WeatherType, timeOfDay: TimeOfDay? = nil) {
        var state = screenState
        state.weather = weather
        if let timeOfDay {
            state.timeOfDay = timeOfDay
        }
        state.backgroundAsset = backgroundAsset(for: state.weather, timeOfDay: state.timeOfDay)
        state.weatherDescription = weatherDescription(for: state.weather)
        screenState = state
    }

    func updateTimeOfDay(_ timeOfDay: TimeOfDay) {
        updateScene(weather: screenState.weather, timeOfDay: timeOfDay)
    }

    func updatePetState(pet: Pet?) {
        var state = screenState
        state.petAsset = petAsset(for: pet?.mood ?? .calm)
        screenState = state
    }

    func moodDescription(for pet: Pet) -> String {
        switch pet.mood {
        case .ecstatic:
            return "Lumio 兴奋地围着你打转"
        case .happy:
            return "Lumio 看见你就开始摇尾巴"
        case .calm:
            return "Lumio 今天心情平静，等着你互动"
        case .sleepy:
            return "Lumio 有点困，摸摸它会更安心"
        case .anxious:
            return "Lumio 有些焦虑，需要你的陪伴"
        case .grumpy:
            return "Lumio 想你了，去哄哄它吧"
        }
    }

    private func petAsset(for mood: PetMood) -> String {
        switch mood {
        case .ecstatic:
            return "foxcurious"
        case .happy:
            return "foxlooking"
        case .calm:
            return "foxlooking"
        case .sleepy:
            return "foxsleep-2"
        case .anxious:
            return "foxsad"
        case .grumpy:
            return "foxtired"
        }
    }

    private func backgroundAsset(for weather: WeatherType, timeOfDay: TimeOfDay) -> String {
        switch (weather, timeOfDay) {
        case (.snowy, _):
            return "bg-main"
        case (.rainy, _):
            return "bg-main"
        case (.windy, _):
            return "bg-main"
        case (.cloudy, .night):
            return "bg-main"
        case (.sunny, .night):
            return "bg-main"
        default:
            return "bg-main"
        }
    }

    private func weatherDescription(for weather: WeatherType) -> String {
        switch weather {
        case .sunny:
            return "外面阳光很好，安排个户外行程吧"
        case .cloudy:
            return "多云也适合散步，别忘了补充水分"
        case .rainy:
            return "下雨天适合在室内放松，点蜡烛和Lumio聊天"
        case .snowy:
            return "飘雪的日子要注意保暖"
        case .windy:
            return "风有点大，先热身再出门"
        }
    }

    private func bondValue(for mood: PetMood) -> Int {
        switch mood {
        case .ecstatic:
            return 85
        case .happy:
            return 70
        case .calm:
            return 55
        case .sleepy:
            return 45
        case .anxious:
            return 35
        case .grumpy:
            return 25
        }
    }

    private func xpRequirement(for level: Int) -> Int {
        switch level {
        case ..<1:
            return 10
        case 1:
            return 10
        case 2:
            return 25
        case 3:
            return 50
        case 4:
            return 75
        case 5:
            return 100
        default:
            return 100
        }
    }
}
