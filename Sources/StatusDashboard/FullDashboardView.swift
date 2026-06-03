import SwiftUI

struct FullDashboardView: View {
    var viewModel: DashboardViewModel
    @State private var selection: SidebarItem? = .overview
    @AppStorage("dashboardAlwaysOnTop") private var alwaysOnTop: Bool = false
    
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
                
                Section("llama.cpp") {
                    Label("Launcher", systemImage: "slider.horizontal.3")
                        .tag(SidebarItem.server)
                    Label("Logs", systemImage: "terminal")
                        .tag(SidebarItem.logs)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("LlamaCenter")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Toggle(isOn: $alwaysOnTop) {
                        Label("Always on Top", systemImage: "macwindow.on.rectangle")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.ultraThinMaterial)
            }
        } detail: {
            VStack(spacing: 0) {
                StatusBannerView(viewModel: viewModel)
                
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
        .onAppear {
            updateWindowLevel()
            NSApp.activate(ignoringOtherApps: true)
        }
        .onChange(of: alwaysOnTop) {
            updateWindowLevel()
        }
    }
    
    private func updateWindowLevel() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "full-dashboard" }) {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
}

struct StatusBannerView: View {
    var viewModel: DashboardViewModel
    @AppStorage("serverPort") private var port: String = "8080"
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isServerManaged ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isServerManaged ? "Server Running" : "Server Offline")
                        .font(.system(.headline, design: .rounded))
                }
                
                if viewModel.isServerManaged {
                    HStack(spacing: 12) {
                        Label("PID: \(viewModel.llmPID ?? 0)", systemImage: "cpu")
                        
                        Button(action: {
                            if let url = URL(string: "http://127.0.0.1:\(port)") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("127.0.0.1:\(port)", systemImage: "safari")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.link)
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
                BannerStat(label: "CPU", value: viewModel.systemCPU, color: .blue)
                BannerStat(label: "GPU", value: viewModel.gpuUsage, color: .orange)
                BannerStat(label: "RAM", value: viewModel.systemMemory, color: .green, suffix: "GB")
            }
            .padding(.trailing, 20)
            
            // Transform to Observer Button
            Button(action: {
                openWindow(id: "observer-mini")
                dismiss() // Close full dashboard
            }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.bordered)
            .help("Transform to Observer Mode")
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct BannerStat: View {
    let label: String
    let value: Double
    let color: Color
    var suffix: String = "%"
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Text("\(Int(value))\(suffix)")
                .font(.system(.subheadline, design: .rounded))
                .bold()
                .foregroundColor(color)
        }
    }
}

struct ServerControlView: View {
    var viewModel: DashboardViewModel
    @AppStorage("serverBinaryPath") private var binaryPath: String = "~/.local/llama.cpp/llama-server"
    @AppStorage("serverPort") private var port: String = "8080"
    @AppStorage("serverPresetPath") private var presetPath: String = "~/.local/models/llama-models.ini"
    @AppStorage("serverExtraArgs") private var extraArgs: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("CONFIGURATION")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
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
                            Label("Start LLAMA Server", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)
                    }
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
    
    private func startServer() {
        var args = ["--host", "127.0.0.1", "--port", port]
        if !presetPath.isEmpty {
            args.append(contentsOf: ["--models-preset", presetPath])
        }
        let extras = extraArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        args.append(contentsOf: extras)
        
        viewModel.startServer(binaryPath: binaryPath, args: args)
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
                        // Line 1: CPU | RAM | GPU
                        HStack(spacing: 24) {
                            InsightItem(label: "CPU", value: "\(viewModel.cpuModel) (\(viewModel.cpuCores) cores)")
                            Divider().frame(height: 12)
                            InsightItem(label: "GPU", value: "\(viewModel.gpuName) (\(Int(viewModel.totalMemory)) GB Shared)")
                            Divider().frame(height: 12)
                            InsightItem(label: "RAM", value: String(format: "%.0f GB Unified", viewModel.totalMemory))
                        }

                        Divider()

                        // Line 2: Service Status
                        HStack(spacing: 24) {
                            ServiceStatusItem(name: "Ollama", isActive: viewModel.hasOllama)
                            Divider().frame(height: 12)
                            ServiceStatusItem(name: "llama.cpp", isActive: viewModel.hasLlamaCpp)
                            Divider().frame(height: 12)
                            ServiceStatusItem(name: "MLX", isActive: viewModel.hasMLX)
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
                    Text("ABOUT LLAMACENTER")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LlamaCenter is your unified control center for local Large Language Models on macOS. It provides native management for **llama.cpp** instances and real-time monitoring for **Ollama** daemons.")
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
                    
                    Text(model.source == .llama ? "LLAMA" : "OLLAMA")
                        .font(.system(size: 8, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(model.source == .llama ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(model.source == .llama ? .blue : .orange)
                        .cornerRadius(3)
                }
                
                Text(model.statusText.capitalized)
                    .font(.caption2.bold())
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
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
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .bold()
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
                VerticalMiniStat(label: "C", value: viewModel.systemCPU, color: .blue)
                VerticalMiniStat(label: "G", value: viewModel.gpuUsage, color: .orange)
                VerticalMiniStat(label: "R", value: viewModel.systemMemory, color: .green, suffix: "G")
            }
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12))
                .foregroundColor(.purple)
                .symbolEffect(.pulse, value: viewModel.isLLMRunning)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
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

struct VerticalMiniStat: View {
    let label: String
    let value: Double
    let color: Color
    var suffix: String = "%"
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
            Text("\(Int(value))\(suffix)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
