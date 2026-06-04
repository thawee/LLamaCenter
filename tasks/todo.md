# Plan: Extend Dashboard to Support MLX Server (mlx_lm.server)

## Problem / Requirement
Extend the LlamaCenter dashboard to monitor and launch the MLX LLM server using `mlx_lm.server` (e.g., with model `jedisct1/gemma-4-12B-it-txt-mlx-8bit`).

## Solutions / Tasks
1. **Process Detection**:
   - Update [ProcessMonitor.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/ProcessMonitor.swift) to detect running processes containing `mlx_lm` or `mlx-lm`.
   - Parse `--model` arguments for MLX processes (including quoted/unquoted repo IDs or local paths) and format their display names as `MLX: [model_name]`.

2. **Launcher / Server Manager Integration**:
   - Add `serverType` enum (`.llamaCpp` or `.mlx`) to let the user select their engine.
   - Update [ServerManager.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/ServerManager.swift) to kill existing `mlx_lm.server` processes if running in MLX mode.
   - Update [DashboardViewModel.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/DashboardViewModel.swift) to support starting/stopping `mlx_lm.server` and detecting if the server is running.
   - Query `/v1/models` endpoint if either llama-server or mlx_lm.server is running (they both implement OpenAI compatibility).

3. **UI / Launcher Controls**:
   - Update [FullDashboardView.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/FullDashboardView.swift):
     - Rename "llama.cpp" section in Sidebar to "Launcher" or "Server" to be engine-agnostic.
     - Add Picker in `ServerControlView` to select the Server Engine (`llama.cpp` or `MLX`).
     - Conditionally show configuration fields:
       - For `llama.cpp`: Show Binary Path, Port, Preset Models (.ini), Extra Arguments.
       - For `MLX`: Show Binary Path (default: `mlx_lm.server`), Port, Model Repo/Path (default: `jedisct1/gemma-4-12B-it-txt-mlx-8bit`), Extra Arguments.
     - Build standard command arguments for launching `mlx_lm.server` with `--model`, `--port`, etc.

4. **Verification**:
   - Build the application using `./build_app.sh`.
   - Verify correct compilation.
   - Review code quality and safety.

## Checklist
- [x] Update `ProcessMonitor.swift` to detect MLX processes and parse model names.
- [x] Add `ServerType` selection to `DashboardViewModel.swift` & update start/stop logic.
- [x] Implement `pkill` logic for `mlx_lm.server` in `ServerManager.swift`.
- [x] Update UI in `FullDashboardView.swift` to allow engine selection and conditional config fields.
- [x] Compile and verify using `./build_app.sh`.
- [x] Implement visual alignments: side-by-side circular gauges in Menu Bar Extra, circular stats in Observer mode, and hardware iconography in System Insights card.
- [x] Document final results and verify code correctness.

## Review / Results
- **Process Detection**: Modified `ProcessMonitor.swift` to match processes containing `mlx_lm` or `mlx-lm` (which covers direct `mlx_lm.server` or execution through python modules like `python -m mlx_lm.server`). Extracted model name or Hugging Face repo ID via regex for `--model` arguments (handling both quoted and unquoted syntax) and prefixed them with a `🍊` emoji in the Processes tab.
- **Server Selection & Launcher**: Added a `ServerType` segmented picker in `FullDashboardView.swift` (`llama.cpp` vs `MLX`).
- **Conditional Configuration**: Custom input forms are rendered depending on the selected engine:
  - For `llama.cpp`: Path to `llama-server` binary, local port, model preset `.ini` file, and extra arguments.
  - For `MLX`: Path/command for `mlx_lm.server` (accepting python syntax like `python3 -m mlx_lm.server`), model repo/path (defaulting to `jedisct1/gemma-4-12B-it-txt-mlx-8bit`), local port, and extra arguments.
- **Unified Model Management**: If an MLX server runs on the configured port, the dashboard queries its OpenAI-compliant `/v1/models` endpoint. Modified `LlamaServerClient` to tolerate model lists missing custom `status` objects, fallback-activating them as loaded.
- **Process Termination**: Updated `ServerManager.swift` to clean up any orphaned or running `mlx_lm.server` processes via `pkill -9 -f mlx_lm.server` when starting or stopping instances.
- **Visual Alignments**:
  - **Menu Bar Extra Dropdown**: Replaced horizontal progress bars with side-by-side circular gauges (CPU, GPU, RAM) with clean hardware icons (`cpu`, `display`, `memorychip`), streamlining space and matching Dashboard styles. Removed the separate "Observer" window toggle from the dropdown, using a unified full-width "Dashboard" launch button.
  - **Observer Mini Mode**: Upgraded vertical stats to matching circular rings showing percentage or absolute unified usage (CPU, GPU, RAM) with inline SF Symbols.
  - **System Insights**: Embedded system-appropriate SF Symbols (`cpu`, `display`, `memorychip`) in the detail cards for visually anchored system specs.
- **Compilation**: Verified successful compilation and packaging into `LlamaCenter.app` using `build_app.sh`.
- **Observer Auto-Start**: Configured `StatusDashboardApp.swift` to automatically launch Observer Mini-mode on start.
- **Observer Mode Toolbar Relocation**: Relocated the "Transform to Observer Mode" button from the Status Banner view into the primary window title bar/toolbar (top-right), giving it a standard native macOS layout.
- **Menu Bar Dismissal**: Fixed the Menu Bar Extra dropdown to programmatically dismiss itself via `@Environment(\.dismiss)` immediately after opening the main dashboard window.
- **Launch at Login**: Implemented a "Launch at Login" toggle in the sidebar bottom toggles area, utilizing the modern AppKit `ServiceManagement` `SMAppService.mainApp` API to cleanly register/unregister the app login item.
- **Version Bump**: Promoted the application version to `v0.1.0` in `build_app.sh` to reflect the comprehensive set of new capabilities (launcher selections, MLX integrations, premium hardware dials, and login services).
- **Application Rebranding**: Fully rebranded the application to **LLM Center** (spaced user-facing name) and **LLMCenter** (bundle and CI workflow filename). Preserved the friendly Llama (`🦙`) emoji inside the dropdown header.



