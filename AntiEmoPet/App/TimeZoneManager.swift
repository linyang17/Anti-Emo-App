import Foundation

final class TimeZoneManager {
    static let shared = TimeZoneManager()

    private init() {}

    // The user's region/city time zone; default to autoupdatingCurrent
    private(set) var timeZone: TimeZone = .autoupdatingCurrent

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    func updateTimeZone(forRegion region: String?) {
        guard let region, !region.isEmpty else {
            timeZone = .autoupdatingCurrent
            return
        }
        // Try to resolve a time zone from the region/city string.
        // Expect formats like "中国-上海" or "英国-伦敦"; use the city part.
        let components = region.split(separator: "-")
        let city = components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? region

        if let tz = TimeZone.knownTimeZoneIdentifiers
            .first(where: { $0.localizedCaseInsensitiveContains(city) })
            .flatMap(TimeZone.init(identifier:)) {
            timeZone = tz
        } else {
            timeZone = .autoupdatingCurrent
        }
    }
}
