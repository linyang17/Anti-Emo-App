import Foundation

struct QueuedSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    var attempts: Int
    let payload: [UserTimeslotSummary]
}

@MainActor
final class DataUploadService {
    private let queueKey = "lumio.upload.queue"

    func enqueue(date: Date, summaries: [UserTimeslotSummary]) {
        guard !summaries.isEmpty else { return }
        var queue = loadQueue()
        let entry = QueuedSummary(id: UUID(), date: date, attempts: 0, payload: summaries)
        queue.append(entry)
        saveQueue(queue)
    }

    func processQueue(sharingEnabled: Bool, uploader: SummaryUploader = SummaryUploader()) async {
        guard sharingEnabled else { return }

		let queue = loadQueue()
        guard !queue.isEmpty else { return }

        var retained: [QueuedSummary] = []
        for var job in queue {
            job.attempts += 1
            let success = await uploader.upload(summaries: job.payload)
            if !success {
                retained.append(job)
            }
        }

        saveQueue(retained)
    }

    func loadQueue() -> [QueuedSummary] {
        guard
            let data = UserDefaults.standard.data(forKey: queueKey),
            let decoded = try? JSONDecoder().decode([QueuedSummary].self, from: data)
        else { return [] }
        return decoded
    }

    private func saveQueue(_ queue: [QueuedSummary]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: queueKey)
    }
}

struct SummaryUploader {
    func upload(summaries: [UserTimeslotSummary]) async -> Bool {
        guard !summaries.isEmpty else { return true }

        // Placeholder uploader: persist payload to a temporary file to simulate network success.
        // Future implementations can swap this with a real HTTP client while reusing the queue logic.
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summaries)
            let filename = "timeslot_summary_\(Int(Date().timeIntervalSince1970)).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
