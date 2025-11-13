import XCTest
@testable import AntiEmoPet

final class GreetingEngineTests: XCTestCase {

	func testBaseGreetingUsesNamePlaceholder() {
		let context = GreetingContext(
			name: "Lin",
			timeSlot: .morning,
			weather: nil,
			lastMood: nil
		)

		let text = GreetingEngine.makeGreeting(from: context)

		XCTAssertTrue(text.contains("Lin") || text.contains("my friend"),
					  "Greeting should include user name or fallback name.")
	}

	func testWeatherGreetingAvailableWhenWeatherProvided() {
		let context = GreetingContext(
			name: "Lin",
			timeSlot: .afternoon,
			weather: .rainy,
			lastMood: nil
		)

		var foundWeatherFlavor = false
		for _ in 0..<10 {
			let text = GreetingEngine.makeGreeting(from: context)
			if text.contains("rainy") || text.contains("Rainy") {
				foundWeatherFlavor = true
				break
			}
		}

		XCTAssertTrue(foundWeatherFlavor,
					  "With rainy weather, greeting should occasionally reflect rainy templates.")
	}

	func testMoodGreetingUsesLastMoodLevel() {
		let context = GreetingContext(
			name: "abcxyz",
			timeSlot: .evening,
			weather: nil,
			lastMood: 10
		)

		var foundLowMood = false
		for _ in 0..<10 {
			let text = GreetingEngine.makeGreeting(from: context)
			if text.contains("heavy") || text.contains("tiny step") {
				foundLowMood = true
				break
			}
		}

		XCTAssertTrue(foundLowMood,
					  "Low lastMood should sometimes trigger low-mood comforting templates.")
	}
}
