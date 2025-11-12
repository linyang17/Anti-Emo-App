import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var currentInput: String = ""
}
