import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var region: String = ""
    @Published var notificationsOptIn: Bool = true

    var canSubmit: Bool {
        !nickname.isEmpty && !region.isEmpty
    }
}
