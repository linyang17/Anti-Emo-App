import Foundation

struct ChatService {
    func reply(to text: String, weather: WeatherType, mood: PetMood) -> String {
        let base: String
        switch weather {
        case .sunny:
            base = "外面有阳光，\(text.contains("累") ? "去晒晒太阳吧" : "记得多补充能量")"
        case .rainy:
            base = "雨声陪你，\(text.contains("冷") ? "泡杯热饮" : "试试室内伸展")"
        case .snowy:
            base = "雪景好美，我们一起慢下来"
        case .cloudy:
            base = "云层再厚，也挡不住你"
        case .windy:
            base = "风有点大，把烦恼吹走"
        }
        let moodLine = "我现在\(mood.displayName)，和你一起加油！"
        return "\(base)。\n\(moodLine)"
    }
}
