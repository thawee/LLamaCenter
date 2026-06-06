import SwiftUI
import AppKit

// MARK: - Window close → hide interceptor

final class DashboardWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?
    var openDashboardAction: (() -> Void)?
    var openObserverAction: (() -> Void)?

    private let dashboardDelegate = DashboardWindowDelegate()

    // Swift 6: NSApplicationDelegate methods are nonisolated by default.
    // Mark them @MainActor so all AppKit access is safe.

    @MainActor
    func applicationWillFinishLaunching(_ notification: Notification) {
        let showDock = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image  = NSImage(systemSymbolName: "brain.head.profile",
                                    accessibilityDescription: "LLM Center")
            button.action = #selector(statusIconClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item      // strong reference keeps the item alive
    }

    @MainActor
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }

    // MARK: - Actions

    @MainActor
    @objc private func statusIconClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        
        if isRightClick {
            let menu = NSMenu()
            
            let openItem = NSMenuItem(title: "Open Dashboard", action: #selector(menuOpenDashboard), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "Quit LLM Center", action: #selector(menuQuit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            if let button = statusItem?.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        } else {
            showDashboard()
        }
    }

    @MainActor
    @objc private func menuOpenDashboard() {
        showDashboard()
    }

    @MainActor
    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    @MainActor
    func showDashboard() {
        // Use SwiftUI's openWindow — Window scene is single-instance,
        // so this just focuses the existing window without creating a new one.
        openDashboardAction?()
    }

    @MainActor
    func onDashboardAppeared(openDashboard: @escaping () -> Void,
                             openObserver:  @escaping () -> Void) {
        openDashboardAction = openDashboard
        openObserverAction  = openObserver
        if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "full-dashboard" }) {
            win.delegate = dashboardDelegate
        }
    }

    @MainActor
    func setRunning(_ running: Bool) {
        statusItem?.button?.contentTintColor = running ? .controlAccentColor : nil
    }
}

// MARK: - App entry point

@main
struct StatusDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = DashboardViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("LLM Center", id: "full-dashboard") {
            FullDashboardView(viewModel: viewModel)
                .frame(minWidth: 700, minHeight: 500)
                .onAppear {
                    appDelegate.onDashboardAppeared(
                        openDashboard: {
                            openWindow(id: "full-dashboard")
                            NSApp.activate(ignoringOtherApps: true)
                        },
                        openObserver: {
                            openWindow(id: "observer-mini")
                        }
                    )
                }
                .onChange(of: viewModel.isLLMRunning) { _, running in
                    appDelegate.setRunning(running)
                }
        }

        Window("Observer", id: "observer-mini") {
            ObserverMiniView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
