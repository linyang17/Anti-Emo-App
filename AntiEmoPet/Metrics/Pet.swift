import Foundation
import SwiftData

enum PetBonding: String, Codable, CaseIterable {
	case ecstatic, happy, curious, sleepy, anxious

	static func from(score: Int) -> PetBonding {
		switch score {
		case 85...100: return .ecstatic
		case 70..<85: return .happy
		case 50..<70: return .curious
		case 30..<50: return .sleepy
		default: return .anxious
		}
	}

}

@Model
final class Pet: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
	var bondingScore: Int
    var level: Int
    var xp: Int
    var decorations: [String]

    init(
        id: UUID = UUID(),
        name: String,
		bondingScore: Int = 30,
        level: Int = 1,
        xp: Int = 0,
        decorations: [String] = []
    ) {
        self.id = id
        self.name = name
		self.bondingScore = bondingScore
        self.level = level
        self.xp = xp
        self.decorations = decorations
    }
}
