import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var tip: String = ""

    func updateTip(weather: WeatherType) {
        switch weather {
        case .sunny:
            tip = "外面阳光正好，完成户外任务能获得更多心情值。"
        case .cloudy:
            tip = "多云也适合出门走走，注意补充维生素 D。"
        case .rainy:
            tip = "雨声是最好的白噪音，安排个室内放松任务。"
        case .snowy:
            tip = "注意保暖，喝杯热饮再出发。"
        case .windy:
            tip = "风有点大，先在室内热身再行动。"
        }
    }
}
