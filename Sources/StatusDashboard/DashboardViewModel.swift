import SwiftUI
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var isLLMRunning: Bool = false
    var systemCPU: Double = 0.0
    var systemMemory: Double = 0.0
    var totalMemory: Double = 64.0 // Initial fallback
    var gpuUsage: Double = 0.0
    
    // Hardware Details
    var cpuModel: String = ""
    var cpuCores: Int = 0
    var gpuName: String = ""
    
    // Service Presence
    var hasOllama: Bool = false
    var hasMLX: Bool = false
    var hasMLXVLM: Bool = false
    var hasLlamaCpp: Bool = false
    
    // LLAMA Specific
    var llmProcessName: String = "None"
    var llmPID: Int32? = nil
    var llmMemory: Double = 0.0
    var allProcesses: [ProcessMonitor.ProcessInfo] = []
    
    // Models
    var loadedModels: [LLMModelStatus] = []
    var isModelsTabActive: Bool = false
    
    // Logs
    var latestLogs: String = ""
    let logFilePath = NSTemporaryDirectory() + "llama-server.log"
    var isServerManaged: Bool = false
    
    private let systemMonitor = SystemMonitor()
    private let processMonitor = ProcessMonitor()
    private let serverClient = LlamaServerClient()
    private let ollamaClient = OllamaClient()
    private let serverManager = ServerManager()
    private var refreshTask: Task<Void, Never>?

    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshStats()
                await refreshLogs()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
    
    func forceRefresh() {
        Task {
            await refreshStats()
        }
    }
    
    @MainActor
    private func refreshLogs() async {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: logFilePath)) {
            if let string = String(data: data, encoding: .utf8) {
                // Get last 50 lines
                let lines = string.components(separatedBy: .newlines)
                self.latestLogs = lines.suffix(50).joined(separator: "\n")
            }
        }
    }
    
    @MainActor
    private func refreshStats() async {
        // Update port from saved settings
        let savedPort = UserDefaults.standard.string(forKey: "serverPort") ?? "8080"
        await serverClient.setPort(savedPort)
        
        // System stats
        let cpu = await systemMonitor.getCPUUsage()
        let mem = await systemMonitor.getMemoryUsage()
        let totalMem = await systemMonitor.getMemoryTotal()
        let gpu = await systemMonitor.getGPUUsage()
        
        // One-time or infrequent hardware probing
        if self.cpuModel.isEmpty {
            self.cpuModel = await systemMonitor.getCPUModel()
            self.cpuCores = await systemMonitor.getCPUCores()
            self.gpuName = await systemMonitor.getGPUName()
        }
        
        // Process stats
        let processes = await processMonitor.findAllLLMProcesses()
        self.allProcesses = processes
        
        // Service Presence Detection
        self.hasOllama = processes.contains(where: { $0.name.localizedCaseInsensitiveContains("ollama") })
        self.hasLlamaCpp = processes.contains(where: { !$0.isMLX && !$0.isMLXVLM && $0.name.localizedCaseInsensitiveContains("llama-server") })
        self.hasMLX = processes.contains(where: { $0.isMLX })
        self.hasMLXVLM = processes.contains(where: { $0.isMLXVLM })
        
        // Recover managed state
        let managedRunning = await serverManager.isRunning()
        let hasLlamaRunning = processes.contains(where: { !$0.isMLX && !$0.isMLXVLM && !$0.name.localizedCaseInsensitiveContains("ollama") })
        let hasMlxRunning = processes.contains(where: { $0.isMLX || $0.isMLXVLM })
        self.isServerManaged = managedRunning || hasLlamaRunning || hasMlxRunning
        
        // Model aggregation
        var allModels: [LLMModelStatus] = self.loadedModels
        
        if isModelsTabActive {
            allModels.removeAll()
            // 1. llama-server or mlx-server models (Only if server is running)
            if hasLlamaRunning || hasMlxRunning {
                let engineSource: LLMModelSource = hasMlxRunning ? (self.hasMLXVLM ? .mlxVlm : .mlx) : .llama
                let serverModels = await serverClient.fetchLoadedModels(source: engineSource)
                allModels.append(contentsOf: serverModels)
            }
            
            // 2. Ollama models
            let ollamaModels = await ollamaClient.fetchModels()
            allModels.append(contentsOf: ollamaModels)
        }
        
        self.loadedModels = allModels
        
        if let primary = processes.first {
            self.systemCPU = cpu
            self.systemMemory = mem
            self.totalMemory = totalMem
            self.gpuUsage = gpu
            self.isLLMRunning = true
            self.llmProcessName = primary.name
            self.llmPID = primary.pid
            self.llmMemory = primary.memoryGB
        } else {
            self.systemCPU = cpu
            self.systemMemory = mem
            self.totalMemory = totalMem
            self.gpuUsage = gpu
            self.isLLMRunning = false
            self.llmProcessName = "None"
            self.llmPID = nil
            self.llmMemory = 0.0
        }
    }
    
    func unloadModel(_ model: LLMModelStatus) {
        Task {
            let success: Bool
            if model.source == .llama {
                success = await serverClient.unloadModel(id: model.id)
            } else {
                success = await ollamaClient.unloadModel(name: model.name)
            }
            if success {
                await refreshStats()
            }
        }
    }

    func loadModel(_ model: LLMModelStatus) {
        Task {
            let success: Bool
            if model.source == .llama {
                success = await serverClient.loadModel(id: model.id)
            } else {
                success = await ollamaClient.loadModel(name: model.name)
            }
            if success {
                await refreshStats()
            }
        }
    }
    
    func stopManagedServer() {
        Task {
            await serverManager.stopServer()
            self.isServerManaged = false
        }
    }
    
    func startServer(binaryPath: String, args: [String]) {
        Task {
            do {
                try await serverManager.startServer(binaryPath: binaryPath, arguments: args, logPath: logFilePath)
                self.isServerManaged = true
            } catch {
                // If it fails, log it so the user can see it in the Logs tab
                let errorMsg = "❌ Failed to start server: \(error.localizedDescription)\n"
                if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                    fileHandle.seekToEndOfFile()
                    if let data = errorMsg.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    try? errorMsg.write(to: URL(fileURLWithPath: logFilePath), atomically: true, encoding: .utf8)
                }
            }
        }
    }
    
    func clearLogs() {
        // Use FileHandle to truncate instead of atomically replacing the file.
        // Atomic replacement creates a new inode, which breaks the running server's pipe.
        if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath)) {
            fileHandle.truncateFile(atOffset: 0)
            fileHandle.closeFile()
            
            Task { @MainActor in
                self.latestLogs = ""
            }
        }
    }
}

struct LLMModelStatus: Identifiable, Hashable {
    let id: String
    var name: String
    var isActive: Bool
    var statusText: String
    var source: LLMModelSource
}

enum LLMModelSource: String, Codable {
    case llama, ollama, mlx, mlxVlm
}

enum ServerType: String, CaseIterable, Identifiable, Codable {
    case llamaCpp = "llama.cpp"
    case mlx = "MLX"
    case mlxVlm = "MLX-VLM"
    
    var id: String { self.rawValue }
}
