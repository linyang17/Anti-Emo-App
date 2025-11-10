import SwiftUI
import Charts

struct MoreView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var window: Int = 14

    var body: some View {
        List {
            Section("情绪 / 能量趋势") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("窗口", selection: $window) {
                        Text("7天").tag(7)
                        Text("14天").tag(14)
                        Text("30天").tag(30)
                    }
                    .pickerStyle(.segmented)

                    if appModel.moodEntries.isEmpty && appModel.energyHistory.isEmpty {
                        Text("暂无记录").foregroundStyle(.secondary)
                    } else {
                        // Mood daily averages
                        let moodData = dailyAverageMood(windowDays: window)
                        DashboardCard(title: "日均情绪", icon: "face.smiling") {
                            if moodData.isEmpty {
                                Text("暂无情绪数据").foregroundStyle(.secondary).frame(height: 160)
                            } else {
                                Chart(moodData.sorted(by: { $0.key < $1.key }), id: \.key) { day, avg in
                                    LineMark(x: .value("日期", day), y: .value("日均情绪", avg))
                                    PointMark(x: .value("日期", day), y: .value("日均情绪", avg))
                                }
                                .frame(height: 180)
                            }
                        }

                        // Energy daily added
                        let energyData = dailyAdded(windowDays: window)
                        DashboardCard(title: "每日补充能量", icon: "bolt.fill") {
                            if energyData.isEmpty {
                                Text("暂无能量数据").foregroundStyle(.secondary).frame(height: 160)
                            } else {
                                Chart(energyData.sorted(by: { $0.key < $1.key }), id: \.key) { day, added in
                                    LineMark(x: .value("日期", day), y: .value("补充", added))
                                    PointMark(x: .value("日期", day), y: .value("补充", added))
                                        .foregroundStyle(.green)
                                }
                                .frame(height: 180)
                            }
                        }
                    }
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

    private func dailyAverageMood(windowDays: Int) -> [Date: Double] {
        let cal = TimeZoneManager.shared.calendar
        let now = Date()
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(1, windowDays) - 1), to: now)!)
        var sums: [Date: (sum: Int, count: Int)] = [:]
        for e in appModel.moodEntries where e.date >= start {
            let d = cal.startOfDay(for: e.date)
            var v = sums[d] ?? (0,0)
            v.sum += e.value
            v.count += 1
            sums[d] = v
        }
        return sums.mapValues { Double($0.sum) / Double(max(1, $0.count)) }
    }

    private func dailyAdded(windowDays: Int) -> [Date: Int] {
        let cal = TimeZoneManager.shared.calendar
        let now = Date()
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(1, windowDays) - 1), to: now)!)
        let sorted = appModel.energyHistory.sorted { $0.date < $1.date }
        var result: [Date: Int] = [:]
        var prev: EnergyHistoryEntry? = nil
        for entry in sorted where entry.date >= start {
            if let p = prev {
                let diff = entry.totalEnergy - p.totalEnergy
                if diff > 0 {
                    let day = cal.startOfDay(for: entry.date)
                    result[day, default: 0] += diff
                }
            }
            prev = entry
        }
        return result
    }
}
