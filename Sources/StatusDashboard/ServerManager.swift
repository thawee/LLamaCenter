import Foundation

actor ServerManager {
    private var process: Process?
    
    func startServer(binaryPath: String, arguments: [String], logPath: String) throws {
        stopServer()
        
        let expandedPath = NSString(string: binaryPath).expandingTildeInPath
        let expandedArgs = arguments.map { NSString(string: $0).expandingTildeInPath }
        
        // Ensure the log file exists
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: expandedPath)
        task.arguments = expandedArgs
        
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
        self.process = task
    }
    
    func stopServer() {
        if let process = process {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        killExistingServers()
        process = nil
    }
    
    // Deinit usually kills standard Process() tasks. 
    // To be extra sure for Option 2, we just don't call terminate in deinit.

    private func killExistingServers() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-9", "llama-server"]
        try? task.run()
        task.waitUntilExit()

        let taskMLX = Process()
        taskMLX.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        taskMLX.arguments = ["-9", "-f", "mlx_lm.server"]
        try? taskMLX.run()
        taskMLX.waitUntilExit()

        let taskMLXVLM = Process()
        taskMLXVLM.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        taskMLXVLM.arguments = ["-9", "-f", "mlx_vlm.server"]
        try? taskMLXVLM.run()
        taskMLXVLM.waitUntilExit()
    }
    
    func isRunning() -> Bool {
        return process?.isRunning ?? false
    }
}
