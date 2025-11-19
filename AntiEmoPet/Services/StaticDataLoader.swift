import Foundation

enum StaticDataError: Error, LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .resourceNotFound(name):
            return "Static resource \(name) was not found in the app bundle."
        case let .decodingFailed(reason):
            return "Failed to decode static data: \(reason)"
        }
    }
}

enum StaticDataLoader {
    private static var cache: [String: Any] = [:]
    private static let decoder = JSONDecoder()
    private static let lock = NSLock()

    static func decode<T: Decodable>(_ resource: String, as type: T.Type = T.self) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[resource] as? T {
            return cached
        }

        guard let url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: "Static") else {
			print("❌ \(resource).json not found in Static folder")
			throw StaticDataError.resourceNotFound(resource)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode(T.self, from: data)
            cache[resource] = decoded
            return decoded
        } catch {
            throw StaticDataError.decodingFailed(error.localizedDescription)
        }
    }
}
