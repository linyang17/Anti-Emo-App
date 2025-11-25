import Foundation
import SwiftUI


actor OnboardingCache {
    static let shared = OnboardingCache()
    private var city: String?
    private var weatherGranted: Bool?

    func setCity(_ c: String) { city = c }
    func getCity() -> String? { city }

    func setWeatherGranted(_ g: Bool) { weatherGranted = g }
    func getWeatherGranted() -> Bool? { weatherGranted }
}


struct GPUCachedBackground: View {
	let name: String
	init(_ name: String) { self.name = name }
	var body: some View {
		Image(name)
			.resizable()
			.scaledToFill()
			.ignoresSafeArea()
	}
}
