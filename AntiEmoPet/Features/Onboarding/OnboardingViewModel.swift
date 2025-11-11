import Foundation
import Combine
internal import CoreLocation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var region: String = ""
    @Published var notificationsOptIn: Bool = true
    @Published var enableLocationAndWeather: Bool = false
    @Published var hasLocationPermission: Bool = false
    @Published var hasWeatherPermission: Bool = false

    var canSubmit: Bool {
        !nickname.isEmpty && !region.isEmpty && enableLocationAndWeather && hasLocationPermission && hasWeatherPermission
    }

    var statusText: String {
        if !enableLocationAndWeather {
            return "请开启定位与天气访问以继续"
        }
        if !hasLocationPermission {
            return "等待定位权限…"
        }
        if !hasWeatherPermission {
            return "等待天气权限…"
        }
        if region.isEmpty {
            return "正在解析城市…"
        }
        return "已准备好"
    }

    func updateLocationStatus(_ status: CLAuthorizationStatus) {
        hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func setWeatherPermission(_ granted: Bool) {
        hasWeatherPermission = granted
    }
}
