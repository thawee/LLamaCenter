import Foundation

actor ServerManager {
    private var processes: [ServerType: Process] = [:]
    
    func startServer(type: ServerType, binaryPath: String, arguments: [String], environment: [String: String]? = nil, logPath: String) throws {
        stopServer(type: type)
        
        let expandedPath = NSString(string: binaryPath).expandingTildeInPath
        let expandedArgs = arguments.map { NSString(string: $0).expandingTildeInPath }
        
        // Ensure the log file exists
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        
        let task = Process()
        if expandedPath.contains("/") {
            task.executableURL = URL(fileURLWithPath: expandedPath)
            task.arguments = expandedArgs
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [expandedPath] + expandedArgs
        }
        
        if let environment = environment {
            var systemEnv = ProcessInfo.processInfo.environment
            for (key, val) in environment {
                systemEnv[key] = val
            }
            task.environment = systemEnv
        }
        
        // Open the log file with O_APPEND so truncating it later works flawlessly
        let fileDescriptor = open(logPath, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        if fileDescriptor != -1 {
            let fileHandle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: true)
            task.standardOutput = fileHandle
            task.standardError = fileHandle
        }
        
        // Set quality of life to avoid killing it on app quit
        task.qualityOfService = .userInitiated
        
        try task.run()
        // We still track it while we are alive, but we won't kill it in deinit
        self.processes[type] = task
    }
    
    func stopServer(type: ServerType) {
        if let process = processes[type] {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        killExistingServer(type: type)
        processes[type] = nil
    }
    
    func stopAllServers() {
        for type in ServerType.allCases {
            stopServer(type: type)
        }
    }
    
    private func killExistingServer(type: ServerType) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-9", type == .llamaCpp ? "llama-server" : "ollama"]
        try? task.run()
        task.waitUntilExit()
    }
    
    func isRunning(type: ServerType) -> Bool {
        return processes[type]?.isRunning ?? false
    }
}
