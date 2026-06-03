import SwiftUI

@main
struct StatusDashboardApp: App {
    @State private var viewModel = DashboardViewModel()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        // The Menu Bar Extra
        MenuBarExtra {
            QuickInfoView(viewModel: viewModel)
        } label: {
            Image(systemName: "brain.head.profile")
                .symbolEffect(.pulse, value: viewModel.isLLMRunning)
        }
        .menuBarExtraStyle(.window)

        // The Full Dashboard Window (Secondary)
        Window("LlamaCenter", id: "full-dashboard") {
            FullDashboardView(viewModel: viewModel)
                .frame(minWidth: 700, minHeight: 500)
        }

        // Observer Mode Mini Window
        Window("Observer", id: "observer-mini") {
            ObserverMiniView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
