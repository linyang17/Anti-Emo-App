import SwiftUI
import SwiftData

@main
struct SunnyPetApp: App {

	// MARK: - Shared Model Container

	static var sharedModelContainer: ModelContainer = {
		let schema = Schema([
			Task.self,
			TaskTemplate.self,
			Pet.self,
			Item.self,
			UserStats.self,
			InventoryEntry.self,
			MoodEntry.self
		])

		// 开发环境可改为 isStoredInMemoryOnly: true 方便每次重置
		let configuration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: true
		)

		do {
			return try ModelContainer(for: schema, configurations: [configuration])
		} catch {
			fatalError("无法创建 ModelContainer: \(error)")
		}
	}()

	// MARK: - App ViewModel

	@StateObject private var appModel: AppViewModel

	init() {
		let container = SunnyPetApp.sharedModelContainer
		let context = ModelContext(container)
		_appModel = StateObject(
			wrappedValue: AppViewModel(
				modelContext: context
			)
		)
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(appModel)
				.onAppear {
					// 在应用启动 / 恢复时加载数据并确保今日任务已生成
					appModel.load()
				}
		}
		.modelContainer(SunnyPetApp.sharedModelContainer)
	}
}
