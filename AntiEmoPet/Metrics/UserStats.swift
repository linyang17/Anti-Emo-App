import Foundation
import SwiftData

enum GenderIdentity: String {
    case male
    case female
    case other
    case unspecified

    var displayName: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        case .unspecified:
            return "Unspecified"
        }
    }
}

@Model
final class UserStats: Identifiable {
    @Attribute(.unique) var id: UUID
    var totalEnergy: Int
    var totalDays: Int
    var lastActiveDate: Date
    var completedTasksCount: Int
    var nickname: String
    var region: String
    var notificationsEnabled: Bool
    var shareLocationAndWeather: Bool
    var gender: String
    var birthday: Date?
    var accountEmail: String
        var isOnboard: Bool
        var regionLocality: String
        var regionAdministrativeArea: String
        var regionCountry: String
        var randomizeTaskTime: Bool
    var hasShownOnboardingCelebration: Bool

    init(
        id: UUID = UUID(),
        totalEnergy: Int = 0,
        streakDays: Int = 0,
        lastActiveDate: Date = .now,
        completedTasksCount: Int = 0,
        nickname: String = "",
        region: String = "",
        notificationsEnabled: Bool = false,
        shareLocationAndWeather: Bool = false,
        gender: String = GenderIdentity.unspecified.rawValue,
        birthday: Date? = nil,
        accountEmail: String = "",
                isOnboard: Bool = false,
                regionLocality: String = "",
                regionAdministrativeArea: String = "",
                regionCountry: String = "",
                randomizeTaskTime: Bool = false,
        hasShownOnboardingCelebration: Bool = false
    ) {
        self.id = id
        self.totalEnergy = totalEnergy
        self.totalDays = streakDays
        self.lastActiveDate = lastActiveDate
        self.completedTasksCount = completedTasksCount
        self.nickname = nickname
        self.region = region
        self.notificationsEnabled = notificationsEnabled
        self.shareLocationAndWeather = shareLocationAndWeather
        self.gender = gender
        self.birthday = birthday
        self.accountEmail = accountEmail
                self.isOnboard = isOnboard
                self.regionLocality = regionLocality
                self.regionAdministrativeArea = regionAdministrativeArea
                self.regionCountry = regionCountry
                self.randomizeTaskTime = randomizeTaskTime
        self.hasShownOnboardingCelebration = hasShownOnboardingCelebration
    }
}
