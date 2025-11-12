import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        List {
            if let stats = appModel.userStats {
                Section("概览") {
                    Label("昵称：\(stats.nickname.isEmpty ? "未设置" : stats.nickname)", systemImage: "person.fill")
                    Label("地区：\(stats.region.isEmpty ? "星球" : stats.region)", systemImage: "mappin.and.ellipse")
                    Label(viewModel.streakDescription(for: stats), systemImage: "flame")
                    Label("完成任务：\(stats.completedTasksCount)", systemImage: "list.clipboard")
                    Label("当前能量：\(stats.totalEnergy)", systemImage: "bolt")
                }

                Section("通知") {
                    Toggle("每日提醒", isOn: Binding(
                        get: { stats.notificationsEnabled },
                        set: { newValue in
                            stats.notificationsEnabled = newValue
                            if newValue {
                                appModel.requestNotifications()
                            }
                            appModel.persistState()
                        }
                    ))
                }
            }
        }
        .navigationTitle("Profile")
    }
}
