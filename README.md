# LLM Center

Native macOS menu bar app to monitor and manage local LLMs (llama.cpp, MLX & Ollama). Featuring real-time hardware metrics, custom server launching, and model management.

## ✨ Features

- **Menu Bar Integration:** Resides in your status bar for quick access to CPU, RAM, and LLAMA metrics.
- **Always-on-Top Dashboard:** A detailed monitoring window with an optional "Always on Top" mode.
- **Server Control:**
  - Start, Stop, and Restart your `llama-server` instance.
  - Automatic cleanup of existing `llama-server` processes on start.
  - Detached execution: The server keeps running even if you close the dashboard.
- **Model Management:**
  - Real-time detection of models in `llama-server` router mode.
  - Interactive **Load** and **Unload** buttons for individual models.
  - Smart process naming: Automatically identifies models from `--alias` or `--model` flags.
- **Real-time Logs:** View live server output with auto-scrolling and a clear-log feature.
- **Privacy First:** 
  - Uses `127.0.0.1` for all internal communication.
  - Supports tilde (`~`) paths for privacy in configuration.

## 🛠️ Requirements

- macOS 14.0 or later.
- `llama.cpp` (specifically `llama-server`) installed locally.
- Xcode Command Line Tools (to build from source).

## 🚀 Getting Started

### Build from Source

1. Clone the repository and navigate to the project directory:
   ```bash
   cd macos-llama-dashboard
   ```

2. Run the build script to create the `.app` bundle:
   ```bash
   chmod +x build_app.sh
   ./build_app.sh
   ```

3. Open the application:
   ```bash
   open "LLMCenter.app"
   ```

## ⚙️ Configuration

Within the **Control** tab of the dashboard:
1. **Binary Path:** Set the path to your `llama-server` executable (e.g., `~/.local/bin/llama-server`).
2. **Port:** Specify the port (defaults to `8080`).
3. **Preset Models File:** Link your `.ini` config file. Use the **Pencil icon** to edit it instantly in your default editor.
4. **Extra Arguments:** Add any additional flags (e.g., `--flash-attn true`).

## 📊 Process Monitoring

The **Processes** tab detects any command line containing `llama-server`, `ollama`, `llama-cli`, or `mlx_lm`. It displays:
- **🦙 Alias:** If the process was started with an `--alias`.
- **📦 Model:** The filename/repo path if started with a `--model` path.
- **Memory & PID:** Real-time resource utilization.

## 👤 Author

**Thawee.p**
- Email: [thaweemail@gmail.com](mailto:thaweemail@gmail.com)

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
