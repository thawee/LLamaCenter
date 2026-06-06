import SwiftUI

struct FullDashboardView: View {
    var viewModel: DashboardViewModel
    @State private var selection: SidebarItem? = .overview
    @AppStorage("dashboardAlwaysOnTop") private var alwaysOnTop: Bool = false
    @AppStorage("showDockIcon") private var showDockIcon: Bool = true
    @AppStorage("autoObserverOnIdle") private var autoObserverOnIdle: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    @State private var eventMonitor: Any? = nil
    @State private var idleTimer: Timer? = nil
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case overview, server, processes, models, logs
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("System") {
                    Label("Overview", systemImage: "sparkles")
                        .tag(SidebarItem.overview)
                    Label("Processes", systemImage: "cpu")
                        .tag(SidebarItem.processes)
                    Label("Models", systemImage: "square.stack.3d.up")
                        .tag(SidebarItem.models)
                }
                
                Section("Server") {
                    Label("Launcher", systemImage: "slider.horizontal.3")
                        .tag(SidebarItem.server)
                    Label("Logs", systemImage: "terminal")
                        .tag(SidebarItem.logs)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("LLM Center")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Toggle(isOn: $alwaysOnTop) {
                        Label("Always on Top", systemImage: "macwindow.on.rectangle")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    
                    Toggle(isOn: $showDockIcon) {
                        Label("Show in Dock", systemImage: "dock.arrow.up.to.window")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    
                    Toggle(isOn: $autoObserverOnIdle) {
                        Label("Auto Observer (5m)", systemImage: "timer")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    
                    Toggle(isOn: $launchAtLogin) {
                        Label("Launch at Login", systemImage: "play.house")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        NSApp.terminate(nil)
                    }) {
                        Label("Quit LLM Center", systemImage: "power")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            }
        } detail: {
            VStack(spacing: 0) {
                StatusBannerView(viewModel: viewModel, selection: $selection)
                
                switch selection {
                case .overview, .none:
                    OverviewView(viewModel: viewModel)
                case .server:
                    ServerControlView(viewModel: viewModel)
                case .processes:
                    ProcessesView(viewModel: viewModel)
                case .models:
                    ModelsView(viewModel: viewModel)
                case .logs:
                    LogsView(viewModel: viewModel)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    openWindow(id: "observer-mini")
                    dismiss()
                }) {
                    Label("Observer Mode", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .help("Transform to Observer Mode")
            }
        }
        .onAppear {
            updateWindowLevel()
            updateActivationPolicy()
            NSApp.activate(ignoringOtherApps: true)
            setupEventMonitor()
            startIdleTimer()
            launchAtLogin = LaunchAtLoginManager.isEnabled
            viewModel.isModelsTabActive = (selection == .models)
            if selection == .models {
                viewModel.forceRefresh()
            }
        }
        .onDisappear {
            removeEventMonitor()
            stopIdleTimer()
            viewModel.isModelsTabActive = false
        }
        .onChange(of: selection) { oldValue, newValue in
            let isModels = (newValue == .models)
            viewModel.isModelsTabActive = isModels
            if isModels {
                viewModel.forceRefresh()
            }
        }
        .onChange(of: alwaysOnTop) {
            updateWindowLevel()
        }
        .onChange(of: showDockIcon) {
            updateActivationPolicy()
        }
        .onChange(of: autoObserverOnIdle) { oldValue, newValue in
            if newValue {
                startIdleTimer()
            } else {
                stopIdleTimer()
            }
        }
        .onChange(of: launchAtLogin) { oldValue, newValue in
            LaunchAtLoginManager.isEnabled = newValue
        }
    }
    
    private func startIdleTimer() {
        idleTimer?.invalidate()
        guard autoObserverOnIdle else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { _ in
            DispatchQueue.main.async {
                openWindow(id: "observer-mini")
                dismiss()
            }
        }
    }
    
    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { event in
            startIdleTimer()
            return event
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func updateWindowLevel() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "full-dashboard" }) {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
    
    private func updateActivationPolicy() {
        if showDockIcon {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
            // Re-activate the application and restore the dashboard window
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "full-dashboard" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}

struct StatusBannerView: View {
    var viewModel: DashboardViewModel
    @Binding var selection: FullDashboardView.SidebarItem?
    @AppStorage("serverPort") private var port: String = "8080"
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isLLMRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isLLMRunning ? "Server Running" : "Server Offline")
                        .font(.system(.headline, design: .rounded))
                }
                
                if viewModel.isLLMRunning {
                    HStack(spacing: 12) {
                        if let pid = viewModel.llmPID {
                            Label("PID: \(pid)", systemImage: "cpu")
                        }
                        
                        let isLlama = viewModel.hasLlamaCpp
                        let engineName = isLlama ? "llama.cpp" : (viewModel.hasMLXVLM ? "MLX-VLM" : (viewModel.hasMLX ? "MLX" : "Ollama"))
                        
                        Text("(\(engineName))")
                            .foregroundColor(.secondary)
                        
                        if isLlama {
                            Button(action: {
                                if let url = URL(string: "http://127.0.0.1:\(port)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.link)
                        } else {
                            Button(action: {
                                selection = .models
                            }) {
                                Label("Manage Models", systemImage: "square.stack.3d.up")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                } else {
                    Text("Ready to launch LLAMA server instance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Persistent Metrics
            HStack(spacing: 24) {
                BannerGaugeStat(label: "CPU", iconName: "cpu", value: viewModel.systemCPU, max: 100, color: .blue)
                BannerGaugeStat(label: "GPU", iconName: "display", value: viewModel.gpuUsage, max: 100, color: .orange)
                BannerGaugeStat(label: "RAM", iconName: "memorychip", value: viewModel.systemMemory, max: viewModel.totalMemory, color: .green, suffix: "GB")
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct BannerGaugeStat: View {
    let label: String
    let iconName: String
    let value: Double
    let max: Double
    let color: Color
    var suffix: String = "%"
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(value / (max > 0 ? max : 1), 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(Angle(degrees: -90))
                
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text("\(Int(value))\(suffix)")
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .foregroundColor(color)
            }
        }
    }
}

struct ServerControlView: View {
    var viewModel: DashboardViewModel
    @AppStorage("serverType") private var serverType: ServerType = .llamaCpp
    
    // llama.cpp settings
    @AppStorage("serverBinaryPath") private var binaryPath: String = "~/.local/llama.cpp/llama-server"
    @AppStorage("serverPresetPath") private var presetPath: String = "~/.local/models/llama-models.ini"
    @AppStorage("serverExtraArgs") private var extraArgs: String = ""
    
    // MLX settings
    @AppStorage("mlxBinaryPath") private var mlxBinaryPath: String = "mlx_lm.server"
    @AppStorage("mlxModel") private var mlxModel: String = "jedisct1/gemma-4-12B-it-txt-mlx-8bit"
    @AppStorage("mlxExtraArgs") private var mlxExtraArgs: String = ""
    
    // MLX-VLM settings
    @AppStorage("mlxVlmBinaryPath") private var mlxVlmBinaryPath: String = "mlx_vlm.server"
    @AppStorage("mlxVlmModel") private var mlxVlmModel: String = "mlx-community/Qwen2.5-VL-7B-Instruct-4bit"
    @AppStorage("mlxVlmExtraArgs") private var mlxVlmExtraArgs: String = ""
    
    // Shared port setting
    @AppStorage("serverPort") private var port: String = "8080"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("CONFIGURATION")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("Server Engine", selection: $serverType) {
                        ForEach(ServerType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if serverType == .llamaCpp {
                        ConfigField(label: "Binary Path", hint: "Full path to your llama-server executable") {
                            HStack {
                                TextField("", text: $binaryPath)
                                    .textFieldStyle(.roundedBorder)
                                Button(action: {
                                    let panel = NSOpenPanel()
                                    panel.canChooseDirectories = false
                                    if panel.runModal() == .OK {
                                        binaryPath = panel.url?.path ?? binaryPath
                                    }
                                }) {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 24) {
                            ConfigField(label: "Port", hint: "Local server port") {
                                TextField("", text: $port)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            ConfigField(label: "Preset Models File (.ini)", hint: "Path to your llama-models.ini") {
                                HStack {
                                    TextField("", text: $presetPath)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: {
                                        let expanded = NSString(string: presetPath).expandingTildeInPath
                                        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
                                    }) {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.bordered)
                                    .help("Edit in default editor")
                                }
                            }
                        }
                        
                        ConfigField(label: "Extra Arguments", hint: "Additional flags for llama-server") {
                            TextField("--flash-attn true --ctx-size 8192", text: $extraArgs)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else if serverType == .mlx {
                        ConfigField(label: "Binary Path / Command", hint: "Command/path to mlx_lm.server (e.g. mlx_lm.server or python3 -m mlx_lm.server)") {
                            TextField("mlx_lm.server", text: $mlxBinaryPath)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(alignment: .top, spacing: 24) {
                            ConfigField(label: "Port", hint: "Local server port") {
                                TextField("", text: $port)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            ConfigField(label: "Model Repo / Path", hint: "Hugging Face repo or local directory path") {
                                TextField("jedisct1/gemma-4-12B-it-txt-mlx-8bit", text: $mlxModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        ConfigField(label: "Extra Arguments", hint: "Additional flags for mlx_lm.server (e.g. --trust-remote-code)") {
                            TextField("", text: $mlxExtraArgs)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        // MLX-VLM
                        ConfigField(label: "Binary Path / Command", hint: "Command/path to mlx_vlm.server (e.g. mlx_vlm.server or python3 -m mlx_vlm.server)") {
                            TextField("mlx_vlm.server", text: $mlxVlmBinaryPath)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(alignment: .top, spacing: 24) {
                            ConfigField(label: "Port", hint: "Local server port") {
                                TextField("", text: $port)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            ConfigField(label: "Model Repo / Path", hint: "Vision-language model HF repo or local path") {
                                TextField("mlx-community/Qwen2.5-VL-7B-Instruct-4bit", text: $mlxVlmModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        ConfigField(label: "Extra Arguments", hint: "Additional flags for mlx_vlm.server (e.g. --trust-remote-code)") {
                            TextField("", text: $mlxVlmExtraArgs)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                HStack(spacing: 16) {
                    if viewModel.isServerManaged {
                        Button(role: .destructive, action: {
                            viewModel.stopManagedServer()
                        }) {
                            Label("Stop Server", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button(action: {
                            viewModel.stopManagedServer()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                startServer()
                            }
                        }) {
                            Label("Restart", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button(action: {
                            startServer()
                        }) {
                            Label(serverType == .llamaCpp ? "Start LLAMA Server" : (serverType == .mlx ? "Start MLX Server" : "Start MLX-VLM Server"), systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)
                    }
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                        .padding(.top, 1)
                    Text("LLM Center manages one active server instance at a time. Starting a new engine will automatically stop any running instance to prevent port conflicts and clean up system resources.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(30)
        }
    }
    
    private func startServer() {
        if serverType == .llamaCpp {
            var args = ["--host", "127.0.0.1", "--port", port]
            if !presetPath.isEmpty {
                args.append(contentsOf: ["--models-preset", presetPath])
            }
            let extras = extraArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            args.append(contentsOf: extras)
            
            viewModel.startServer(binaryPath: binaryPath, args: args)
        } else if serverType == .mlx {
            var fullBinaryPath = mlxBinaryPath.trimmingCharacters(in: .whitespaces)
            var args: [String] = []
            
            // Check if user specifies command starting with python
            if fullBinaryPath.hasPrefix("python") {
                let parts = fullBinaryPath.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count > 1 {
                    fullBinaryPath = parts[0]
                    args.append(contentsOf: parts[1...])
                }
            }
            
            args.append(contentsOf: ["--model", mlxModel, "--port", port])
            
            let extras = mlxExtraArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            args.append(contentsOf: extras)
            
            viewModel.startServer(binaryPath: fullBinaryPath, args: args)
        } else {
            // MLX-VLM
            var fullBinaryPath = mlxVlmBinaryPath.trimmingCharacters(in: .whitespaces)
            var args: [String] = []
            
            // Check if user specifies command starting with python
            if fullBinaryPath.hasPrefix("python") {
                let parts = fullBinaryPath.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count > 1 {
                    fullBinaryPath = parts[0]
                    args.append(contentsOf: parts[1...])
                }
            }
            
            args.append(contentsOf: ["--model", mlxVlmModel, "--port", port])
            
            let extras = mlxVlmExtraArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            args.append(contentsOf: extras)
            
            viewModel.startServer(binaryPath: fullBinaryPath, args: args)
        }
    }
}

struct OverviewView: View {
    var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // System Information (llmfit style)

                VStack(alignment: .leading, spacing: 12) {
                    Text("SYSTEM INSIGHTS")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 24) {
                            InsightItem(label: "CPU", iconName: "cpu", value: "\(viewModel.cpuModel) (\(viewModel.cpuCores) cores)")
                            Divider().frame(height: 12)
                            InsightItem(label: "GPU", iconName: "display", value: "\(viewModel.gpuName) (\(Int(viewModel.totalMemory)) GB Shared)")
                            Divider().frame(height: 12)
                            InsightItem(label: "RAM", iconName: "memorychip", value: String(format: "%.0f GB Unified", viewModel.totalMemory))
                        }

                        Divider()

                        // Line 2: Service Status
                        HStack(spacing: 24) {
                            ServiceStatusItem(name: "Ollama", isActive: viewModel.hasOllama)
                            Divider().frame(height: 12)
                            ServiceStatusItem(name: "llama.cpp", isActive: viewModel.hasLlamaCpp)
                            Divider().frame(height: 12)
                            ServiceStatusItem(name: "MLX", isActive: viewModel.hasMLX)
                            Divider().frame(height: 12)
                            ServiceStatusItem(name: "MLX-VLM", isActive: viewModel.hasMLXVLM)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                }

                
                VStack(alignment: .leading, spacing: 16) {
                    Text("ABOUT LLM CENTER")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LLM Center is your unified control center for local Large Language Models on macOS. It provides native launcher management for **llama.cpp**, **MLX**, and **MLX-VLM**, alongside real-time monitoring for **Ollama** daemons.")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Use the **Launcher** to manage custom server instances, or the **Models** tab to interact with your installed GGUF and Ollama model library.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
    
    private func getHardwareName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        let data = machine.withUnsafeBufferPointer { Data(buffer: $0) }
        return String(decoding: data.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
}

struct ModelsView: View {
    var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Model Management")
                    .font(.title2.bold())
                
                if !viewModel.loadedModels.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(viewModel.loadedModels) { model in
                            ModelRow(model: model, onUnload: {
                                viewModel.unloadModel(model)
                            }, onLoad: {
                                viewModel.loadModel(model)
                            })
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    ContentUnavailableView("No Models Detected", systemImage: "square.stack.3d.up.slash", description: Text("Start llama-server in router mode or Ollama to manage models."))
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

struct ProcessesView: View {
    var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("LLAMA Processes")
                    .font(.title2.bold())
                
                if !viewModel.allProcesses.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(viewModel.allProcesses, id: \.pid) { process in
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(process.name)
                                        .font(.body.monospaced())
                                    Text("PID: \(process.pid)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.2f GB", process.memoryGB))
                                    .font(.body.monospacedDigit())
                            }
                            .padding()
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    ContentUnavailableView("No Processes Detected", systemImage: "cpu.slash", description: Text("No running LLM servers found."))
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

struct LogsView: View {
    var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Server Logs")
                    .font(.title2.bold())
                Spacer()
                Text(viewModel.logFilePath)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.latestLogs.isEmpty ? "No logs available. Start the server via Launcher to view output." : viewModel.latestLogs)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("logContent")
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .onChange(of: viewModel.latestLogs) {
                    proxy.scrollTo("logContent", anchor: .bottom)
                }
            }
            
            HStack {
                Text("Showing last 50 lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear Log File") {
                    viewModel.clearLogs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(30)
    }
}

struct MetricCard: View {
    let label: String
    let value: Double
    let color: Color
    var max: Double = 100
    var suffix: String = "%"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(value))")
                    .font(.system(.title, design: .rounded).bold())
                Text(suffix)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: value, total: max)
                .tint(color)
        }
        .padding()
        .frame(minWidth: 140)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ModelRow: View {
    let model: LLMModelStatus
    let onUnload: () -> Void
    let onLoad: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "cube.box.fill")
                .foregroundColor(model.isActive ? .purple : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.body.monospaced())
                        .lineLimit(1)
                    
                    Text(model.source == .llama ? "LLAMA" : (model.source == .mlx ? "MLX" : (model.source == .mlxVlm ? "MLX-VLM" : "OLLAMA")))
                        .font(.system(size: 8, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            model.source == .llama ? Color.blue.opacity(0.1) :
                            (model.source == .mlx ? Color.purple.opacity(0.1) :
                            (model.source == .mlxVlm ? Color.pink.opacity(0.1) : Color.orange.opacity(0.1)))
                        )
                        .foregroundColor(
                            model.source == .llama ? .blue :
                            (model.source == .mlx ? .purple :
                            (model.source == .mlxVlm ? .pink : .orange))
                        )
                        .cornerRadius(3)
                }
                
                Text(model.statusText.capitalized)
                    .font(.caption2.bold())
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            if model.source != .mlx && model.source != .mlxVlm {
                if model.isActive {
                    Button("Unload") {
                        onUnload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if model.statusText == "unloaded" {
                    Button("Load") {
                        onLoad()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if model.statusText == "loading" {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
            }
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch model.statusText {
        case "loaded": return .green
        case "loading": return .orange
        case "unloaded": return .secondary
        default: return .red
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.subheadline)
    }
}

struct InsightItem: View {
    let label: String
    let iconName: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .bold()
            }
        }
    }
}

struct ServiceStatusItem: View {
    let name: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(name):")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 10))
                .foregroundColor(isActive ? .green : .secondary)
            
            Text(isActive ? "Active" : "Offline")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? .green : .secondary)
        }
    }
}

struct ConfigField<Content: View>: View {
    let label: String
    let hint: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.subheadline.bold())
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            content()
        }
    }
}

// MARK: - Observer Mode Views

struct ObserverMiniView: View {
    var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Observer")
                
                Button(action: {
                    openWindow(id: "full-dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                    dismiss()
                }) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Full Dashboard")
            }
            
            VStack(spacing: 14) {
                CircularMiniStat(iconName: "cpu", value: viewModel.systemCPU, max: 100, color: .blue)
                CircularMiniStat(iconName: "display", value: viewModel.gpuUsage, max: 100, color: .orange)
                CircularMiniStat(iconName: "memorychip", value: viewModel.systemMemory, max: viewModel.totalMemory, color: .green, suffix: "G")
            }
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12))
                .foregroundColor(.purple)
                .symbolEffect(.pulse, value: viewModel.isLLMRunning)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(minWidth: 46)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "observer-mini" }) {
                window.level = .floating
                window.isMovableByWindowBackground = true
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = true
                
                // Completely remove the title bar region to fix empty space
                window.styleMask.remove(.titled)
                window.styleMask.insert(.borderless)
            }
        }
    }
}

struct CircularMiniStat: View {
    let iconName: String
    let value: Double
    let max: Double
    let color: Color
    var suffix: String = "%"
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(value / (max > 0 ? max : 1), 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(Angle(degrees: -90))
                
                Image(systemName: iconName)
                    .font(.system(size: 9))
                    .foregroundColor(color)
            }
            
            Text("\(Int(value))\(suffix)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
