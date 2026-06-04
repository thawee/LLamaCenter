# Design Spec: Rebrand Application to LLM Center

**Date**: 2026-06-04  
**Author**: Antigravity  

## Background
The application has evolved from only supporting `llama.cpp` server instances to hosting multiple local execution engines, including Apple Silicon-native MLX (`mlx_lm.server`) and acting as a monitor for local `Ollama` services. Rebranding the application to a more general, engine-agnostic name while preserving its friendly identity aligns the user interface with its actual expanded utility.

## Goals
1. Rebrand user-facing instances of "LlamaCenter" to "LLM Center".
2. Keep the friendly llama icon (`🦙`) to represent local LLM execution.
3. Update bundle identifier, build output name, and GitHub Actions configuration to use the new name `LLMCenter`.

## Proposed Design

### 1. Build and Bundle Names
* **Xcode/SwiftPM App Bundle**: `LLMCenter.app` (no spaces for cleaner command-line and directory scripting).
* **Bundle Identifier**: `com.user.LLMCenter` (updated in `build_app.sh`).
* **Info.plist CFBundleName**: `LLM Center` (updated in `build_app.sh`).

### 2. User Interface Strings
* **Menu Bar Header** in `QuickInfoView.swift`: `🦙 LLM Center`
* **Sidebar Navigation Title** in `FullDashboardView.swift`: `LLM Center`
* **Sidebar Description Text** in `FullDashboardView.swift` (Overview Tab):
  > "LLM Center is your unified control center for local Large Language Models on macOS. It provides native launcher management for **llama.cpp** and **MLX**, alongside real-time monitoring for **Ollama** daemons."
* **Secondary Window title** in `StatusDashboardApp.swift`: `LLM Center`

### 3. CI and Release Config
* Update `.github/workflows/release.yml` commands to zip and publish `LLMCenter.zip` and `LLMCenter.app`.
* Update references in `README.md`.

## Verification
1. Verify compilation succeeds.
2. Confirm the built bundle is output to `LLMCenter.app`.
3. Confirm double-clicking or executing `open LLMCenter.app` launches the app correctly under the new name.
