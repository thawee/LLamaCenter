import Foundation

actor ProcessMonitor {
    struct ProcessInfo {
        let pid: Int32
        let name: String
        let memoryGB: Double
    }
    
    func findAllLLMProcesses() -> [ProcessInfo] {
        let task = Process()
        task.launchPath = "/bin/ps"
        // -o command: gives the full executable path and arguments
        task.arguments = ["-ax", "-o", "pid,rss,command"]

        let pipe = Pipe()
        task.standardOutput = pipe

        var found: [ProcessInfo] = []

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }

                    let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 3 else { continue }

                    let pidStr = parts[0]
                    let rssStr = parts[1]
                    let fullCommand = parts[2...].joined(separator: " ")

                    // Priority Match: Any process path containing "llama-server"
                    // Also check for ollama variants
                    let isLLAMA = fullCommand.localizedCaseInsensitiveContains("llama-server") || 
                                 fullCommand.localizedCaseInsensitiveContains("ollama") ||
                                 fullCommand.localizedCaseInsensitiveContains("llama-cli")

                    if isLLAMA, let pid = Int32(pidStr), let rss = Double(rssStr) {
                        // Avoid adding the dashboard itself
                        if !fullCommand.contains("StatusDashboard") {
                            let url = URL(fileURLWithPath: parts[2])
                            var displayName = url.lastPathComponent.isEmpty ? "llama-server" : url.lastPathComponent

                            // Try to guess model name from --alias
                            if let aliasRange = fullCommand.range(of: "--alias\\s+([^\\s]+)", options: .regularExpression) {
                                let match = fullCommand[aliasRange]
                                if let name = match.components(separatedBy: .whitespaces).last {
                                    displayName = "🦙 \(name)"
                                }
                            } 
                            // Fallback to --model filename if no alias
                            else if let modelRange = fullCommand.range(of: "--model\\s+([^\\s]+)", options: .regularExpression) {
                                let match = fullCommand[modelRange]
                                if let path = match.components(separatedBy: .whitespaces).last {
                                    let modelUrl = URL(fileURLWithPath: path)
                                    displayName = "📦 \(modelUrl.lastPathComponent)"
                                }
                            }

                            let mem = rss / (1024 * 1024) // KB -> GB
                            found.append(ProcessInfo(pid: pid, name: displayName, memoryGB: mem))
                        }
                    }

                }
            }
        } catch {
            // Ignore errors for permissions/missing ps command
        }
        
        var uniquePIDs = Set<Int32>()
        return found.filter { uniquePIDs.insert($0.pid).inserted }
    }
}
