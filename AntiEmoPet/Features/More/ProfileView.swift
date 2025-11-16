import SwiftUI


struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            if let stats = appModel.userStats {
                Section("User Info") {
                    Label("Username：\(stats.nickname.isEmpty ? "human unknown" : stats.nickname)", systemImage: "person.fill")
                    Label("City：\(stats.region.isEmpty ? "city unknown" : stats.region)", systemImage: "mappin.and.ellipse")
                    if !stats.accountEmail.isEmpty {
                        Label("Account：\(stats.accountEmail)", systemImage: "envelope")
                    }
                    Label("You've met Lumio \(stats.TotalDays) days", systemImage: "flame")
					// TODO: add current streak days
                    Label("Tasks completed：\(stats.completedTasksCount)", systemImage: "list.clipboard")
                }

                Section("Membership Status") {
					
					// TODO: add membership status
					
					Label("Basic", systemImage: "questionmark")
					
                }
            }
        }
        .navigationTitle("Profile")
    }
}

