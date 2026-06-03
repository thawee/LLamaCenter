import Foundation

actor SystemMonitor {
    private var lastTicks: host_cpu_load_info?
    
    func getCPUUsage() -> Double {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        if let last = lastTicks {
            let user = Double(loadInfo.cpu_ticks.0 - last.cpu_ticks.0)
            let sys = Double(loadInfo.cpu_ticks.1 - last.cpu_ticks.1)
            let idle = Double(loadInfo.cpu_ticks.2 - last.cpu_ticks.2)
            let nice = Double(loadInfo.cpu_ticks.3 - last.cpu_ticks.3)

            let total = user + sys + idle + nice
            lastTicks = loadInfo
            return total > 0 ? ((total - idle) / total) * 100.0 : 0.0
        }
 else {
            lastTicks = loadInfo
            return 0.0
        }
    }
    
    func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let pageSize = UInt64(getpagesize())
        let active = UInt64(stats.active_count) * pageSize
        let wire = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        
        let used = Double(active + wire + compressed) / (1024 * 1024 * 1024) // GB
        return used
    }

    func getMemoryTotal() -> Double {
        var size: UInt64 = 0
        var sizeLen = MemoryLayout<UInt64>.size
        let result = sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0)
        guard result == 0 else { return 64.0 } // Default fallback
        return Double(size) / (1024 * 1024 * 1024)
    }
    
    func getCPUModel() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let data = brand.withUnsafeBufferPointer { Data(buffer: $0) }
        return String(decoding: data.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
    
    func getCPUCores() -> Int {
        var cores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.ncpu", &cores, &size, nil, 0)
        return Int(cores)
    }
    
    func getGPUName() -> String {
        // Method 1: Check for AGXAccelerator model property
        let task = Process()
        task.launchPath = "/usr/bin/ioreg"
        task.arguments = ["-r", "-c", "AGXAccelerator", "-d", "1"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for "model" = <"Apple M3 Pro"> or "model" = "Apple M3 Pro"
                let patterns = ["\"model\"\\s*=\\s*<\"([^\"]+)\">", "\"model\"\\s*=\\s*\"([^\"]+)\""]
                for pattern in patterns {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let range = NSRange(output.startIndex..<output.endIndex, in: output)
                    if let match = regex.firstMatch(in: output, options: [], range: range) {
                        if let valueRange = Range(match.range(at: 1), in: output) {
                            return String(output[valueRange])
                        }
                    }
                }
            }
        } catch {}
        
        // Method 2: Fallback to a simpler name or CPU brand if M-series
        let cpuBrand = getCPUModel()
        if cpuBrand.contains("Apple M") {
            return cpuBrand.components(separatedBy: " (")[0]
        }
        
        return "Apple Silicon"
    }
    
    func getGPUUsage() -> Double {
        let task = Process()
        task.launchPath = "/usr/bin/ioreg"
        task.arguments = ["-r", "-c", "AGXAccelerator", "-d", "2"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for "Device Utilization %"
                let pattern = "\"Device Utilization %\"\\s*=\\s*(\\d+)"
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(output.startIndex..<output.endIndex, in: output)
                
                if let match = regex.firstMatch(in: output, options: [], range: range) {
                    if let valueRange = Range(match.range(at: 1), in: output) {
                        return Double(output[valueRange]) ?? 0.0
                    }
                }
            }
        } catch {
            return 0.0
        }
        return 0.0
    }
}
