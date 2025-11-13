import Foundation
import Combine

@MainActor
final class SleepReminderService: ObservableObject {
    @Published private(set) var isReminderDue = false

    private var monitorTask: Task<Void, Never>?
    private var hasPresentedInSession = false
    private let calendar = Calendar.current

    func startMonitoring() {
        resetSession()
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300 * 1_000_000_000)
                await MainActor.run { self.evaluateReminder() }
                if self.hasPresentedInSession { break }
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func acknowledgeReminder() {
        isReminderDue = false
    }

    private func resetSession() {
        isReminderDue = false
        hasPresentedInSession = false
    }

    private func evaluateReminder() {
        guard !hasPresentedInSession else { return }
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        if hour >= 22 || hour < 6 {
            hasPresentedInSession = true
            isReminderDue = true
        }
    }

    deinit {
        monitorTask?.cancel()
    }
}
