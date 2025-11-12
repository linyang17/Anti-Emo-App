import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = TasksViewModel()

    var body: some View {
        List {
            Section() {
                ForEach(appModel.todayTasks) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.title)
                                .font(.headline)
                            Text(viewModel.badge(for: task))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            appModel.toggleTask(task)
                        } label: {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
								.foregroundStyle(task.status == .completed ? .black.opacity(0.5) : .secondary)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                }
            }
            if appModel.todayTasks.isEmpty {
                Section {
                    Text("暂无任务，稍后再试或检查网络")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("刷新") {
                    Task { await viewModel.forceRefresh(appModel: appModel) }
                }
            }
        }
    }
}
