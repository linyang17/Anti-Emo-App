import SwiftUI

struct ToolbarEnergy: ViewModifier {
    @ObservedObject var appModel: AppViewModel

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let energy = appModel.userStats?.totalEnergy {
                    Label("\(energy)", systemImage: "bolt")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

extension View {
    func energyToolbar(appModel: AppViewModel) -> some View {
        modifier(ToolbarEnergy(appModel: appModel))
    }
}
