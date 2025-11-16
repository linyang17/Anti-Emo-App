import SwiftUI
import SwiftData

@main
struct LumioPetApp: App {

	// MARK: - Shared Model Container
	static var sharedModelContainer: ModelContainer = {
		let schema = Schema([
			UserTask.self,
			TaskTemplate.self,
			Pet.self,
			Item.self,
			UserStats.self,
			InventoryEntry.self,
			MoodEntry.self
		])

		// 使用持久化配置，确保数据在重启后保持一致
		let configuration = ModelConfiguration(schema: schema)

		do {
			return try ModelContainer(for: schema, configurations: [configuration])
		} catch {
			fatalError("Can't create ModelContainer: \(error.localizedDescription)")
		}
	}()

	// MARK: - App ViewModel
	@StateObject private var appModel: AppViewModel

	init() {
		let container = LumioPetApp.sharedModelContainer
		let context = ModelContext(container)
		_appModel = StateObject(wrappedValue: AppViewModel(modelContext: context))
	}

	// MARK: - Scene Definition
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(appModel)
                                .environment(\.font, FontTheme.body)
				.task {
					// 应用启动时加载数据（task 自动在主 actor 上运行）
					await appModel.load()
				}
				.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
					// 应用回到前台时刷新
					Task { await appModel.refreshIfNeeded() }
				}
		}
		.modelContainer(LumioPetApp.sharedModelContainer)
	}
}
