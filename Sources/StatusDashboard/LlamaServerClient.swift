import Foundation

actor LlamaServerClient {
    private var port: String = "8080"
    private var baseURL: URL {
        URL(string: "http://localhost:\(port)")!
    }
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        return URLSession(configuration: config)
    }()
    
    func setPort(_ newPort: String) {
        self.port = newPort
    }
    
    struct ModelResponse: Codable {
        let data: [ModelInfo]
    }
    
    struct ModelInfo: Codable {
        let id: String
        let status: ModelStatus?
    }
    
    struct ModelStatus: Codable {
        let value: String // "loaded", "unloaded", "loading", etc.
    }
    
    func fetchLoadedModels(source: LLMModelSource = .llama) async -> [LLMModelStatus] {
        let url = baseURL.appendingPathComponent("v1/models")
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(ModelResponse.self, from: data)
            return response.data
                .filter { $0.id != "default" }
                .map { info in
                    LLMModelStatus(
                        id: info.id,
                        name: info.id,
                        isActive: info.status?.value == "loaded" || info.status == nil,
                        statusText: info.status?.value ?? "loaded",
                        source: source
                    )
                }
        } catch {
            return []
        }
    }
    
    func unloadModel(id: String) async -> Bool {
        let url = baseURL.appendingPathComponent("models/unload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["model": id]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func loadModel(id: String) async -> Bool {
        let url = baseURL.appendingPathComponent("models/load")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["model": id]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
