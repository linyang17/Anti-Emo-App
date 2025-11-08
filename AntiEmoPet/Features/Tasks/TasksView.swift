import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = TasksViewModel()

    var body: some View {
        List {
            Section(header: Text("今日任务")) {
                ForEach(appModel.todayTasks) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.title)
                                .font(.headline)
                            Text(viewModel.subtitle(for: task))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(viewModel.badge(for: task))
                            .font(.caption.bold())
                            .padding(6)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                        Button {
                            appModel.toggleTask(task)
                        } label: {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.status == .completed ? .green : .secondary)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            if appModel.todayTasks.isEmpty {
                Section {
                    Text("暂无任务，稍后再试或检查网络")
                }
            }
        }
        .onAppear {
            appModel.ensureInitialTasks()
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
        .energyToolbar(appModel: appModel)
    }
}
