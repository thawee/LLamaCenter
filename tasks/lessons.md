# Lessons Learned

## macOS App Visibility & Crowded Menu Bar Accessibility

### Problem
A menu-bar-only app (`LSUIElement` set to `true`) can become completely inaccessible to users if their macOS menu bar is full/crowded, or on notched devices where icons are hidden under the notch.

### Design Decisions & Patterns
1. **Dynamic Activation Policy (`NSApp.setActivationPolicy`)**:
   - Provide a setting (`showDockIcon`) to let the user choose whether they want the app to be visible in the Dock.
   - Use `NSApp.setActivationPolicy(.regular)` to show the Dock icon and standard menus, and `NSApp.setActivationPolicy(.accessory)` to run purely in the background (menu-bar only).
   - This can be done safely on the main thread at runtime.

2. **Handle Reopen Events (`applicationShouldHandleReopen`)**:
   - Register an `NSApplicationDelegate` using `@NSApplicationDelegateAdaptor`.
   - Implement `applicationShouldHandleReopen(_:hasVisibleWindows:)` to handle click events on the application icon in Finder, Applications folder, or Spotlight.
   - When triggered, open the main/settings window of the app. This guarantees that even if the icon is hidden, the user can always access the app by re-launching it.

3. **Bridge Swift/AppKit Delegate to SwiftUI Window Routing**:
   - Inside the main scene (e.g. `MenuBarExtra` or static app struct), assign the SwiftUI `@Environment(\.openWindow)` action into a callback property on the `AppDelegate`.
   - Use a clear view `.onAppear` modifier inside the label of `MenuBarExtra` to register this callback, as it is guaranteed to execute immediately on application start.

4. **Swift 6 Concurrency & Actor-Isolation for App Delegates**:
   - `AppDelegate` must be marked `@MainActor` to run its callbacks safely on the main actor.
   - When referencing properties/callbacks inside asynchronously-scheduled closures (like `DispatchQueue.main.async`), capture the variables directly (e.g. `if let action = openWindowAction`) instead of capturing `self` to avoid data race warnings/errors.

## macOS App Lifecycle & Early NSApp Initialization Crash

### Problem
Calling `NSApp.setActivationPolicy(...)` inside `init()` of a SwiftUI `App` structure can cause a fatal crash because `NSApp` (which translates to `NSApplication.shared`) is still `nil` at that point in the application lifecycle.

### Design Decisions & Patterns
- **Leverage Application Delegate**: Move any initial application window/policy configuration to the `NSApplicationDelegate` callback `applicationWillFinishLaunching(_:)`.
- **Timing Guarantee**: When `applicationWillFinishLaunching` is invoked, `NSApp` is guaranteed to be fully initialized and non-nil.

## API Compatibility & Model Capabilities (e.g. MLX)

### Problem
Certain OpenAI-compatible local engines (like `mlx_lm.server`) only host the model they were started with and do not support dynamic `/models/load` or `/models/unload` endpoints. Classifying them as generic `LLAMA` model sources leads to display errors and non-functional buttons.

### Design Decisions & Patterns
- **Differentiated Source Mapping**: Distinguish processes using an explicit enum case (`.mlx` source) based on process detection, rather than mapping all generic API servers as `.llama`.
- **Conditional UI Interaction**: Hide action buttons (Load/Unload) for engines that do not support dynamic loading, while maintaining visibility of the active model and status.

## Robust Process and Engine Classification

### Problem
Relying on checks against formatted display names (e.g. `$0.name.contains("mlx_lm")`) to classify process engines in the dashboard is brittle and error-prone, as display names are often stripped of binary paths and prefixed with emoji markers (like `🍊` or `📦`).

### Design Decisions & Patterns
- **Store Metadata at Source**: Attach structural classification metadata directly to internal data structures (e.g., adding `isMLX: Bool` to the `ProcessInfo` struct at the time of process identification).
- **Decouple Logic from Display Names**: Avoid using UI-facing display strings for state checking, routing, or classification. Use raw structural fields instead.

## macOS Activation Policy Changes & Window Preservation

### Problem
Changing the activation policy of an application dynamically from `.regular` to `.accessory` automatically hides or closes all open windows of that app. Toggling "Show in Dock" off in the dashboard would therefore cause the dashboard window itself to disappear.

### Design Decisions & Patterns
- **Restore Window Visibility Async**: Whenever switching the application activation policy to `.accessory` at runtime, schedule an asynchronous block on the main queue (`DispatchQueue.main.async`) to reactivate the application (`NSApp.activate`) and restore key state to the target window using `window.makeKeyAndOrderFront(nil)`. This prevents the window from being hidden when the Dock icon disappears.

## Application Idle State Tracking in SwiftUI/AppKit

### Problem
Detecting application/window inactivity (idle state) in a SwiftUI-only app lacks direct APIs for mouse movement and keyboard event tracking.

### Design Decisions & Patterns
- **Use NSEvent Local Monitor**: Register a local event monitor via `NSEvent.addLocalMonitorForEvents(matching:handler:)` in the view's `.onAppear` block.
- **Event Scope**: Capture events like `.mouseMoved`, `.leftMouseDown`, `.rightMouseDown`, and `.keyDown` to capture all user activity within the app window.
- **Timer Invalidation**: Use standard `Timer` instances, invalidating and rescheduling them whenever a local event is received.
- **Cleanup**: Retain a reference to the event monitor object and explicitly call `NSEvent.removeMonitor(monitor)` in the view's `.onDisappear` block to prevent memory leaks and dangling monitors.
