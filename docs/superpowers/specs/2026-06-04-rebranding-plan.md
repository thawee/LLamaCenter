# Implementation Plan: Rebrand LlamaCenter to LLM Center

## Overview
Rebrand the application name, metadata, and user interface texts to "LLM Center" (`LLMCenter`) to align with its capability as an engine-agnostic local LLM controller.

## Task List

### Phase 1: Build & Configurations (XS)
- [ ] **Task 1**: Update build settings and workflow
  - **Description**: Rename the built application and configuration bundle identifiers.
  - **Files touched**:
    - [build_app.sh](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/build_app.sh)
    - [.github/workflows/release.yml](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/.github/workflows/release.yml)
  - **Acceptance criteria**:
    - `APP_NAME` in `build_app.sh` is `"LLMCenter"`.
    - `BUNDLE_ID` in `build_app.sh` is `"com.user.LLMCenter"`.
    - `release.yml` references zip file as `LLMCenter.zip` and builds `LLMCenter.app`.
  - **Verification**:
    - Files edited correctly.

### Phase 2: Code & UI Rebranding (S)
- [ ] **Task 2**: Rename user-facing interface text and headers
  - **Description**: Rename occurrences of "LlamaCenter" in views and files to "LLM Center" with the llama `🦙` emoji.
  - **Files touched**:
    - [Sources/StatusDashboard/QuickInfoView.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/QuickInfoView.swift)
    - [Sources/StatusDashboard/FullDashboardView.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/FullDashboardView.swift)
    - [Sources/StatusDashboard/StatusDashboardApp.swift](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/Sources/StatusDashboard/StatusDashboardApp.swift)
    - [README.md](file:///Users/thawee.p/Workspaces/github/macos-LLamaCenter/README.md)
  - **Acceptance criteria**:
    - Menu Bar extra title in `QuickInfoView` is `🦙 LLM Center`.
    - Sidebar navigation title in `FullDashboardView` is `LLM Center`.
    - App description in `FullDashboardView` matches the new support list (llama.cpp, MLX, Ollama).
    - Window title in `StatusDashboardApp` is `LLM Center`.
  - **Verification**:
    - Run `./build_app.sh` and ensure the project builds correctly.

### Checkpoint: Complete Rebrand
- [ ] Rebuilding app via `./build_app.sh` succeeds with output `LLMCenter.app`.
- [ ] Executing `open LLMCenter.app` launches the app correctly under the user-facing name "LLM Center".
