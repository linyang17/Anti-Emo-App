import Foundation
import Combine

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
            levelLabel: "LV 1",
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
			summary.bond = pet.bondingScore
            let requirement = XPProgression.requirement(for: pet.level)
            let clampedRequirement = max(requirement, 1)
            let progress = Double(max(0, min(pet.xp, clampedRequirement))) / Double(clampedRequirement)
            summary.experienceProgress = min(max(progress, 0), 1)
            summary.levelLabel = "LV \(pet.level)"
        } else {
            summary.bond = 30
            summary.experienceProgress = 0
            summary.levelLabel = ""
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
		let bondingState = PetBonding.from(score: pet!.bondingScore)
		state.petAsset = petAsset(for: bondingState)
        screenState = state
    }


    func petAsset(for bonding: PetBonding) -> String {
        switch bonding {
        case .ecstatic:
            return "foxplaying"
        case .happy:
            return "foxhappy"
		case .relaxed:
			return "foxrelax"
		case .familiar:
			return "foxnormal"
        case .curious:
            return "foxcurious"
        case .sleepy:
            return "foxsleep"
        case .anxious:
            return "foxtired"
		}
    }

    private func backgroundAsset(for weather: WeatherType, timeOfDay: TimeOfDay) -> String {
		// TODO: add animation and change background day/night
        switch (weather, timeOfDay) {
        case (.snowy, _):
            return "bg-snow"
		case (.rainy, _):
            return "bg-main"
		case (.cloudy, .day):
            return "bg-dawn"
        case (_, .night):
            return "bg-night"
        default:
            return "bg-main"
        }
    }

    private func weatherDescription(for weather: WeatherType) -> String {
        switch weather {
        case .sunny:
            return "Sunny outide, let's go outdoors!"
        case .cloudy:
            return "Fancy a walk or some exercise?"
        case .rainy:
            return "Rainy days are perfect for a movie or a cozy read."
        case .snowy:
            return "It's snowing! Do you want to build a snowman? Let's build a snowman!"
        case .windy:
            return "WOOOOOOSH! The wind is blowing, remember to wear some warm clothing!"
        }
    }
}
