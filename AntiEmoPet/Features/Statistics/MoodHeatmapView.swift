import SwiftUI

struct MoodHeatmapView: View {
    let data: [TimeSlot: [Int: Double]]
    
    // 1=Sun, 2=Mon, ..., 7=Sat
    // We want Mon(2) -> Sun(1) order: 2,3,4,5,6,7,1
    let weekdays = [2, 3, 4, 5, 6, 7, 1]
    let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // TimeSlot order: Morning, Afternoon, Evening, Night
    private let timeSlots: [TimeSlot] = [.morning, .afternoon, .evening, .night]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header (Weekdays)
            HStack(spacing: 4) {
                Text("") // Spacer for Y axis labels
                    .frame(width: 60)
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day.prefix(1))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid
            ForEach(timeSlots, id: \.self) { slot in
                HStack(spacing: 4) {
                    // Y Axis Label
                    Text(slot.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    
                    // Cells
                    ForEach(weekdays, id: \.self) { day in
                        if let moodValue = data[slot]?[day] {
                            Cell(value: moodValue)
                        } else {
                            Cell(value: nil)
                        }
                    }
                }
            }
        }
    }
    
    private struct Cell: View {
        let value: Double?
        
        var body: some View {
            RoundedRectangle(cornerRadius: 4)
                .fill(color(for: value))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let v = value {
                        Text("\(Int(v))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
        }
        
        private func color(for value: Double?) -> Color {
            guard let v = value else { return Color.gray.opacity(0.1) }
            
            if v < 40 {
                return Color.blue.opacity(0.3 + (v / 40.0) * 0.4)
            } else if v < 70 {
                return Color.yellow.opacity(0.3 + ((v - 40) / 30.0) * 0.4)
            } else {
                return Color.pink.opacity(0.3 + ((v - 70) / 30.0) * 0.6)
            }
        }
    }
}

