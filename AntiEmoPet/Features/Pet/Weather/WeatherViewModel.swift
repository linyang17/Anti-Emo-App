import Foundation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var tip: String = ""
    @Published var moodValue: Int = 50
    
    var saveMood: () -> Void = {}

    func updateTip(weather: WeatherType) {
        switch weather {
        case .sunny:
            tip = "外面阳光正好，去外面晒晒太阳有助于心情哦。"
        case .cloudy:
            tip = "多云也适合出门走走，注意补充维生素 D。"
        case .rainy:
            tip = "雨声是最好的白噪音，安排个室内放松吧。"
        case .snowy:
            tip = "注意保暖，喝杯热饮再出发。"
        case .windy:
            tip = "风有点大，先在室内热身再出门吧。"
        }
    }

    func loadLatestMood(from appModel: AppViewModel) {
        if let latest = appModel.moodEntries.first {
            moodValue = latest.value
        }
    }
}
