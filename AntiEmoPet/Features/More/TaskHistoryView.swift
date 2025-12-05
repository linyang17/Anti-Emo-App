import SwiftUI

struct TaskHistoryView: View {
        @EnvironmentObject private var appModel: AppViewModel
        @State private var sections: [TaskHistorySection] = []
        @State private var exportURL: URL?
        @State private var errorMessage: String?

        private let historyDays = 30

        var body: some View {
                List {
                        Section("Export") {
                                Button {
                                        exportHistory()
                                } label: {
                                        Label("Export last \(historyDays) days", systemImage: "square.and.arrow.up")
                                }
                                .disabled(appModel.taskHistorySections(days: historyDays).isEmpty)

                                if let exportURL {
                                        ShareLink(item: exportURL) {
                                                Label("Share export file", systemImage: "arrow.up.forward.app")
                                        }
                                }
                        }

                        ForEach(sections) { section in
                                Section(header: Text(dateLabel(for: section.date))) {
                                        ForEach(section.tasks) { task in
                                                VStack(alignment: .leading, spacing: 6) {
                                                        Text(task.title)
                                                                .font(.headline)
                                                        HStack(spacing: 10) {
                                                                TagView(text: task.category.localizedTitle)
                                                                TagView(text: task.status.rawValue.capitalized)
                                                                if task.isArchived {
                                                                        TagView(text: "Archived")
                                                                }
                                                        }
                                                        if let completed = task.completedAt {
                                                                Text("Completed at \(timeLabel(for: completed))")
                                                                        .font(.caption)
                                                                        .foregroundColor(.secondary)
                                                        }
                                                }
                                        }
                                }
                        }
                }
                .navigationTitle("History")
                .onAppear { loadHistory() }
                .alert("Export failed", isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { newValue in if !newValue { errorMessage = nil } }
                )) {
                        Button("OK", role: .cancel) { }
                } message: {
                        Text(errorMessage ?? "Unknown error")
                }
        }

        private func loadHistory() {
                sections = appModel.taskHistorySections(days: historyDays)
        }

        private func exportHistory() {
                guard let url = appModel.exportTaskHistory(days: historyDays) else {
                        errorMessage = "Could not generate export file."
                        return
                }
                exportURL = url
        }

        private func dateLabel(for date: Date) -> String {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
        }

        private func timeLabel(for date: Date) -> String {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                return formatter.string(from: date)
        }
}

private struct TagView: View {
        let text: String

        var body: some View {
                Text(text)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
        }
}
