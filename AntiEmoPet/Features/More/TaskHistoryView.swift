import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TaskHistoryView: View {
        @EnvironmentObject private var appModel: AppViewModel
        @State private var sections: [TaskHistorySection] = []
        @State private var exportURL: URL?
        @State private var errorMessage: String?
        @State private var isImporting = false
        @State private var importMessage: String?
        @State private var isSharingExport = false

        private let historyDays = 90
        private var excelTypes: [UTType] {
                [UTType(filenameExtension: "xls"), UTType(filenameExtension: "xlsx")].compactMap { $0 }
        }

        var body: some View {
                List {
                        Section("Export") {
                                Button {
                                        exportHistory()
                                } label: {
                                        Label("Export last \(historyDays) days", systemImage: "square.and.arrow.up")
                                }
                                .disabled(appModel.taskHistorySections(days: historyDays).isEmpty)

                                Button {
                                        isImporting = true
                                } label: {
                                        Label("Import data", systemImage: "square.and.arrow.down")
                                }
                        }
					//#if !DEBUG
                        ForEach(sections) { section in
                                Section(header: Text(dateLabel(for: section.date))) {
                                        ForEach(section.tasks) { task in
                                                VStack(alignment: .leading, spacing: 6) {
                                                        Text(task.title)
															.appFont(FontTheme.body)
                                                        HStack(spacing: 10) {
                                                                TagView(text: task.category.localizedTitle)
                                                                TagView(text: task.status.rawValue.capitalized)
                                                                if task.isArchived {
                                                                        TagView(text: "Archived")
                                                                }
                                                        }
                                                        if let completed = task.completedAt {
                                                                Text("Completed at \(timeLabel(for: completed))")
																		.appFont(FontTheme.caption)
                                                                        .foregroundColor(.secondary)
                                                        }
                                                }
                                        }
                                }
                        }
					//#endif
                }
                .navigationTitle("History")
                .onAppear { loadHistory() }
                .alert("Error", isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { newValue in if !newValue { errorMessage = nil } }
                )) {
                        Button("OK", role: .cancel) { }
                } message: {
                        Text(errorMessage ?? "Unknown error")
                }
                .alert("Import", isPresented: Binding(
                        get: { importMessage != nil },
                        set: { newValue in if !newValue { importMessage = nil } }
                )) {
                        Button("OK", role: .cancel) { }
                } message: {
                        Text(importMessage ?? "")
                }
                .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: excelTypes + [.data]
                ) { result in
                        switch result {
                        case .success(let url):
                                let success = appModel.importTaskHistory(from: url)
                                if success {
                                        loadHistory()
                                        importMessage = "Import succeeded."
                                } else {
                                        errorMessage = "Import failed."
                                }
                        case .failure(let error):
                                errorMessage = error.localizedDescription
                        }
                }
                .sheet(isPresented: $isSharingExport) {
                        if let exportURL {
                                ShareSheet(activityItems: [exportURL])
                        }
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
                isSharingExport = true
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

private struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
                UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct TagView: View {
        let text: String

        var body: some View {
                Text(text)
						.appFont(FontTheme.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
        }
}
