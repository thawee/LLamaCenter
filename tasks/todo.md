# Plan: Review Changes, Update Version & Commit

## Phase 2: Review and Release

- [x] Run `git diff` to review all changes in detail and verify correctness.
- [x] Update version to `0.3.0` in `build_app.sh`.
- [x] Verify the build runs cleanly with the updated version using `./build_app.sh`.
- [x] Stage and commit changes using Conventional Commits structure (`feat: support concurrent engines and collapsible sidebar`).
- [x] Document results in `tasks/todo.md`.

## Review / Results
- **Code Review**: Verified all changes across `ServerManager`, `ProcessMonitor`, `OllamaClient`, `DashboardViewModel`, `FullDashboardView`, and documentation. All MLX references were successfully dropped, and concurrent server control pathways are sound.
- **Version Bump**: Bumped the release version to `0.3.0` inside `build_app.sh`.
- **Build Verification**: Cleanly compiled and packaged the app bundle (`LLMCenter.app`) under version `0.3.0`.
- **Commit**: Completed semantic commit `feat: support concurrent llama.cpp/ollama engines and collapsible sidebar` capturing all code and resource changes.
