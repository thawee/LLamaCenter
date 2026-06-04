import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var openObserverAction: (@MainActor () -> Void)? {
        didSet {
            if shouldOpenOnLaunch {
                shouldOpenOnLaunch = false
                if let action = openObserverAction {
                    DispatchQueue.main.async {
                        action()
                    }
                }
            }
        }
    }
    var openDashboardAction: (@MainActor () -> Void)?
    
    private var shouldOpenOnLaunch = true
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let showDock = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
        if showDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let openDashboardAction = openDashboardAction {
            openDashboardAction()
        } else {
            shouldOpenOnLaunch = true
        }
        return true
    }
}

@main
struct StatusDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = DashboardViewModel()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        // The Menu Bar Extra
        MenuBarExtra {
            QuickInfoView(viewModel: viewModel)
        } label: {
            Image(systemName: "brain.head.profile")
                .symbolEffect(.pulse, value: viewModel.isLLMRunning)
                .background(
                    Color.clear
                        .onAppear {
                            appDelegate.openObserverAction = {
                                openWindow(id: "observer-mini")
                            }
                            appDelegate.openDashboardAction = {
                                openWindow(id: "full-dashboard")
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }
                )
        }
        .menuBarExtraStyle(.window)

        // The Full Dashboard Window (Secondary)
        Window("LLM Center", id: "full-dashboard") {
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

