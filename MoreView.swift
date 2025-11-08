import SwiftUI
import Charts

struct MoreView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            Section("情绪 / 能量趋势") {
                if appModel.moodEntries.isEmpty && appModel.energyHistory.isEmpty {
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(appModel.moodEntries.prefix(30).reversed()) { entry in
                            LineMark(
                                x: .value("日期", entry.date),
                                y: .value("情绪", entry.value)
                            )
                            .symbol(by: .value("类型", "情绪"))
                        }
                        ForEach(appModel.energyHistory.suffix(30)) { entry in
                            LineMark(
                                x: .value("日期", entry.date),
                                y: .value("能量", entry.totalEnergy)
                            )
                            .symbol(by: .value("类型", "能量"))
                        }
                    }
                    .frame(height: 220)
                }
            }

            Section("历史记录") {
                ForEach(appModel.moodEntries) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        HStack(spacing: 6) {
                            ProgressView(value: Double(entry.value) / 100.0)
                                .frame(width: 120)
                                .progressViewStyle(LinearProgressViewStyle())
                            Text("\(entry.value)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("记录")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("Energy: \(appModel.totalEnergy)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
