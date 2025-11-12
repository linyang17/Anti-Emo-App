import SwiftUI
import Charts

struct OtherView: View {
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

        }
        .navigationTitle("记录")
    }
}
