import Foundation
import os.log

struct AnalyticsService {
    private let logger = Logger(subsystem: "com.sunny.pet", category: "analytics")

    func log(event: String, metadata: [String: String] = [:]) {
        let details = metadata.map { "\($0.key):\($0.value)" }.joined(separator: ", ")
        logger.log("\(event, privacy: .public) -- \(details, privacy: .public)")
    }
}
