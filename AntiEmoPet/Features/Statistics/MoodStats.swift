import SwiftUI

struct MoodStatsSection: View {
    let mood: MoodStatisticsViewModel.MoodSummary

    var body: some View {
        DashboardCard(title: "Mood Summary", icon: "face.smiling") {
            VStack(alignment: .leading, spacing: 8) {
				
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Latest：")
						.appFont(FontTheme.title3)
                    Text("\(mood.lastMood) ")
						.appFont(FontTheme.title3)
						.bold()
                    if !mood.trend.rawValue.isEmpty {
                        Image(systemName: mood.trend.rawValue)
							.appFont(FontTheme.headline)
							.foregroundStyle(mood.trend == .up ? .green : (mood.trend == .down ? .red : .primary))
							.bold()
                    }
                }

				
				Divider().padding(.vertical, 6)
				
				HStack(spacing: 20){
					VStack(alignment: .leading, spacing: 12) {
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Today")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.averageToday)")
								.appFont(FontTheme.headline)
								.bold()
						}
						VStack(alignment: .leading, spacing: 5) {
							Text("Recorded Days")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.uniqueDayCount)")
								.appFont(FontTheme.headline)
								.bold()
						}
					}
					Spacer()
					
					VStack(alignment: .leading, spacing: 12) {
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Past Week")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.averagePastWeek)")
								.appFont(FontTheme.headline)
								.bold()
						}
						VStack(alignment: .leading, spacing: 5) {
							Text("Total Decords")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text("\(mood.entriesCount)")
								.appFont(FontTheme.headline)
								.bold()
						}
					}
				}
					.frame(maxWidth: .w(0.8))
					.padding(.bottom, 12)
				
                Text(mood.comment.isEmpty ? "Come more often for summary" : mood.comment)
					.bold()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}
