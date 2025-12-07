import SwiftUI


struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            if let stats = appModel.userStats {
                Section("User Info") {
                    Label("Username：\(stats.nickname.isEmpty ? "Some human unknown" : stats.nickname)", systemImage: "person.fill")
                    Label("City：\(stats.formattedRegion.isEmpty ? "Somewhere on the Earth" : stats.formattedRegion)", systemImage: "mappin.and.ellipse")
                    if !stats.accountEmail.isEmpty {
                        Label("Account：\(stats.accountEmail)", systemImage: "envelope")
                    }
                }
				
				Section("Log") {
					Label("You've met Lumio for: \(stats.totalDays) days", systemImage: "flame")
					// TODO: add current streak days
					Label("Total tasks completed：\(stats.completedTasksCount)", systemImage: "checkmark.circle")
				}
				
            }
        }
        .navigationTitle("Profile")
    }
}

private extension UserStats {
	var formattedRegion: String {
		let parts = [regionLocality, regionAdministrativeArea, regionCountry]
			.filter { !$0.isEmpty }
		let combined = parts.joined(separator: ", ")
		return combined.isEmpty ? region : combined
	}
}

