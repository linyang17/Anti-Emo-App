import SwiftUI
import Charts

struct MoreView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            Section("情绪趋势") {
                if appModel.moodEntries.isEmpty {
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(appModel.moodEntries.prefix(30).reversed(), id: \.id) { entry in
                        LineMark(
                            x: .value("日期", entry.date),
                            y: .value("情绪", entry.value)
                        )
                    }
                    .frame(height: 180)
                }
            }

            Section("历史记录") {
                ForEach(appModel.moodEntries) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        Text("\(entry.value)")
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("More")
    }
}
