import SwiftUI

struct MoodStatsSection: View {
    let mood: MoodStatisticsViewModel.MoodSummary

    var body: some View {
        DashboardCard(title: "Mood Summary", icon: "face.smiling") {
            VStack(alignment: .leading, spacing: 8) {
				
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Latest：")
                        .font(.title2.weight(.semibold))
                    Text("\(mood.lastMood)")
						.font(.title2.weight(.semibold))
                    if !mood.trend.rawValue.isEmpty {
                        Image(systemName: mood.trend.rawValue)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

				
				Divider().padding(.vertical, 6)
				HStack(spacing: 20){
					VStack(alignment: .leading, spacing: 12) {
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Today")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.averageToday)")
								.font(.title3.weight(.medium))
						}
						VStack(alignment: .leading, spacing: 5) {
							Text("Recorded Days")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.uniqueDayCount)")
								.font(.title3.weight(.medium))
						}
					}
					Spacer()
					
					VStack(alignment: .leading, spacing: 12) {
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Past Week")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.averagePastWeek)")
								.font(.title3.weight(.medium))
						}
						VStack(alignment: .leading, spacing: 5) {
							Text("Total Decords")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.entriesCount)")
								.font(.title3.weight(.medium))
						}
					}
				}
					.frame(maxWidth: 280)
					.padding(.bottom, 12)
				
                Text(mood.comment.isEmpty ? "Come more often for summary" : mood.comment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}
