//
//  AntiEmoPetTests.swift
//  AntiEmoPetTests
//
//  Created by Selena Yang on 07/11/2025.
//

import Testing
import SwiftData
@testable import AntiEmoPet

@MainActor
struct AntiEmoPetTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Task.self,
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
        let tasks = generator.generateTasks(for: .now, weather: .sunny)

        #expect((3...6).contains(tasks.count))
        #expect(tasks.allSatisfy { $0.weatherType == .sunny })
    }

    @Test("RewardEngine grants energy + streak") func rewardEngineGrantsEnergy() throws {
        let stats = UserStats(totalEnergy: 10, coins: 5, streakDays: 0, completedTasksCount: 0)
        let task = Task(title: "Test", weatherType: .sunny, difficulty: .medium, date: .now, status: .completed)

        let rewardEngine = RewardEngine()
        let gained = rewardEngine.applyTaskReward(for: task, stats: stats)

        #expect(gained == task.difficulty.energyReward)
        #expect(stats.totalEnergy == 10 + gained)
        #expect(stats.completedTasksCount == 1)
    }

    @Test("PetEngine reacts to feeding and levelling") func petEngineFeedAndLevel() throws {
        let pet = Pet(name: "Sunny", mood: .calm, hunger: 40, level: 1, xp: 95)
        let snack = Item(sku: "snack.energy.bar", type: .snack, name: "Bar", costEnergy: 10, moodBoost: 4, hungerBoost: 20)

        let engine = PetEngine()
        engine.handleAction(.feed(item: snack), pet: pet)

        #expect(pet.hunger > 40)
        #expect(pet.level == 2) // xp wraps to next level
        #expect(pet.xp < 10)
    }

    @Test("ChatService stub responds with mood line") func chatServiceResponds() {
        let reply = ChatService().reply(to: "有点累", weather: .rainy, mood: .happy)
        #expect(reply.contains("雨声陪你"))
        #expect(reply.contains("开心"))
    }
}
