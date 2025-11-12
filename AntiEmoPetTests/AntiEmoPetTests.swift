//
//  AntiEmoPetTests.swift
//  AntiEmoPetTests
//
//  Created by Selena Yang on 07/11/2025.
//

import Testing
import SwiftData
@testable import AntiEmoPet
import Foundation

@MainActor
struct AntiEmoPetTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            UserTask.self,
            TaskTemplate.self,
            Pet.self,
            Item.self,
            UserStats.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("Storage bootstraps default records / 数据种子") func storageBootstrapsSeeds() throws {
        let container = try makeInMemoryContainer()
        let storage = StorageService(context: container.mainContext)
        storage.bootstrapIfNeeded()

        #expect(storage.fetchPet() != nil)
        #expect(storage.fetchStats() != nil)
        #expect(!storage.fetchShopItems().isEmpty)
    }

    @Test("Task generator respects weather templates") func taskGeneratorMatchesWeather() throws {
        let container = try makeInMemoryContainer()
        let storage = StorageService(context: container.mainContext)
        storage.bootstrapIfNeeded()

        let generator = TaskGeneratorService(storage: storage)
		let tasks = generator.generateDailyTasks(for: Date.now, report: <#WeatherReport?#>)

        #expect((3...6).contains(tasks.count))
        #expect(tasks.allSatisfy { $0.weatherType == WeatherType.sunny })
    }

    @Test("RewardEngine grants energy + streak") func rewardEngineGrantsEnergy() throws {
        let stats = UserStats(totalEnergy: 10, coins: 5, streakDays: 0, completedTasksCount: 0)
        let task = UserTask(
						title: "Test",
						weatherType: WeatherType.sunny,
						difficulty: .medium,
						category: .outdoor,
						energyReward: 10,
						date: Date.now,
						status: .completed
						)

        let rewardEngine = RewardEngine()
        let gained = rewardEngine.applyTaskReward(for: task, stats: stats)

        #expect(gained == task.energyReward)
        #expect(stats.totalEnergy == 10 + gained)
        #expect(stats.completedTasksCount == 1)
    }

    @Test("PetEngine reacts to feeding and levelling") func petEngineFeedAndLevel() throws {
        let pet = Pet(name: "Lumio", bonding: .calm, hunger: 40, level: 1, xp: 95)
        let snack = Item(sku: "snack.energy.bar", type: .snack, name: "Bar", costEnergy: 10, BondingBoost: 4, hungerBoost: 20)

        let engine = PetEngine()
        engine.handleAction(.feed(item: snack), pet: pet)

        #expect(pet.hunger > 40)
        #expect(pet.level == 2) // xp wraps to next level
        #expect(pet.xp < 10)
    }

    @Test("ChatService stub responds with bonding line") func chatServiceResponds() {
        let reply = ChatService().reply(to: "有点累", weather: .rainy, bonding: .happy)
        #expect(reply.contains("雨声陪你"))
        #expect(reply.contains("开心"))
    }

    @Test("Default seeds create fresh model instances") func defaultSeedsAreCopyable() {
        let firstBatch = DefaultSeeds.makeItems()
        let secondBatch = DefaultSeeds.makeItems()

        let zipped = zip(firstBatch, secondBatch)
        #expect(!zipped.contains { $0.0 === $0.1 })
        #expect(zipped.allSatisfy { $0.0.sku == $0.1.sku && $0.0.id != $0.1.id })
    }

    @Test("Bootstrapping twice does not duplicate records") func bootstrapIsIdempotent() throws {
        let container = try makeInMemoryContainer()
        let storage = StorageService(context: container.mainContext)

        storage.bootstrapIfNeeded()
        let firstItems = storage.fetchShopItems()
        let firstTemplates = storage.fetchTemplates()

        storage.bootstrapIfNeeded()
        let secondItems = storage.fetchShopItems()
        let secondTemplates = storage.fetchTemplates()

        #expect(firstItems.count == secondItems.count)
        #expect(firstTemplates.count == secondTemplates.count)
        let energyCosts = firstItems.map(\.costEnergy)
        #expect(energyCosts == energyCosts.sorted())
    }

    @Test("Storage returns tasks sorted by date") func fetchTasksReturnsChronologicalOrder() throws {
        let container = try makeInMemoryContainer()
        let storage = StorageService(context: container.mainContext)

        let calendar = Calendar(identifier: .gregorian)
        let baseDate = calendar.startOfDay(for: .now)
        let morning = calendar.date(byAdding: .hour, value: 8, to: baseDate) ?? baseDate
        let evening = calendar.date(byAdding: .hour, value: 20, to: baseDate) ?? baseDate

        storage.save(tasks: [
            UserTask(title: "Evening", weatherType: .cloudy, difficulty: .medium,
						category: .social,
						energyReward: 10,
						date: evening,
						status: .completed),
            UserTask(title: "Morning", weatherType: .sunny, difficulty: .easy,
						category: .indoorDigital,
						energyReward: 10,
						date: evening,
						status: .completed),
        ])

        let tasks = storage.fetchTasks(for: baseDate)
        #expect(tasks.map(\.title) == ["Morning", "Evening"])
    }
}
