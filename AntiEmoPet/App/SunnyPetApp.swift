import SwiftUI
import SwiftData

@main
struct SunnyPetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Task.self,
            TaskTemplate.self,
            Pet.self,
            Item.self,
            UserStats.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
