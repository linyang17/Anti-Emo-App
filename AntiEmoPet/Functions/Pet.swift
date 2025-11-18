import Foundation
import SwiftData

enum PetBonding: String, Codable, CaseIterable {
	case ecstatic, happy, curious, sleepy, anxious

	var displayName: String {
		switch self {
		case .ecstatic: return "活力满满"
		case .happy: return "开始摇尾巴"
		case .curious: return "有点无聊"
		case .sleepy: return "困困"
		case .anxious: return "好想好想你"
		}
	}

	static func from(score: Int) -> PetBonding {
		switch score {
		case 90...100: return .ecstatic
		case 70..<90: return .happy
		case 50..<70: return .curious
		case 30..<50: return .sleepy
		default: return .anxious
		}
	}

	static func defaultScore(for bonding: PetBonding) -> Int {
		switch bonding {
		case .ecstatic: return 95
		case .happy: return 80
		case .curious: return 60
		case .sleepy: return 40
		case .anxious: return 20
		}
	}
}

@Model
final class Pet: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var bonding: PetBonding
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
        self.bonding = PetBonding.from(score: bondingScore)
        self.level = level
        self.xp = xp
        self.decorations = decorations
    }
}
