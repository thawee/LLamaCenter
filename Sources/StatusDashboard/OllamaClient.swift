import Foundation

actor OllamaClient {
    private var port: String = "11434"
    private var baseURL: URL {
        URL(string: "http://localhost:\(port)")!
    }
    
    func setPort(_ newPort: String) {
        self.port = newPort
    }
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        return URLSession(configuration: config)
    }()
    
    struct TagsResponse: Codable {
        let models: [OllamaModel]
    }
    
    struct OllamaModel: Codable {
        let name: String
        let size: Int64
    }
    
    struct RunningResponse: Codable {
        let models: [RunningModel]
    }
    
    struct RunningModel: Codable {
        let name: String
        let size: Int64
        let digest: String
    }
    
    func fetchModels() async -> [LLMModelStatus] {
        // Fetch all installed models
        let tagsUrl = baseURL.appendingPathComponent("api/tags")
        let runningUrl = baseURL.appendingPathComponent("api/ps")
        
        do {
            let (tagsData, _) = try await session.data(from: tagsUrl)
            let tagsResponse = try JSONDecoder().decode(TagsResponse.self, from: tagsData)
            
            let (psData, _) = try await session.data(from: runningUrl)
            let psResponse = try? JSONDecoder().decode(RunningResponse.self, from: psData)
            let runningNames = Set(psResponse?.models.map { $0.name } ?? [])
            
            return tagsResponse.models.map { model in
                LLMModelStatus(
                    id: "ollama-\(model.name)",
                    name: model.name,
                    isActive: runningNames.contains(model.name),
                    statusText: runningNames.contains(model.name) ? "loaded" : "unloaded",
                    source: .ollama
                )
            }
        } catch {
            return []
        }
    }
    
    func unloadModel(name: String) async -> Bool {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "model": name,
            "keep_alive": 0
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func loadModel(name: String) async -> Bool {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "model": name,
            "prompt": ""
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
