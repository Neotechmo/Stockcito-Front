import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "URL inválida"
        case .invalidResponse:       return "Respuesta inválida del servidor"
        case .unauthorized:          return "Sesión expirada. Inicia sesión de nuevo."
        case .serverError(let msg):  return msg
        case .decodingError(let msg):return "Error al parsear respuesta: \(msg)"
        }
    }
}

class APIClient {
    static let shared = APIClient()
    private init() {}

    var baseURL: String {
        UserDefaults.standard.string(forKey: "api_base_url")
            ?? "https://api.neotechmo.top/Stockcito/api" 
    }

    var token: String? {
        get { UserDefaults.standard.string(forKey: "jwt_token") }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "jwt_token") }
            else { UserDefaults.standard.removeObject(forKey: "jwt_token") }
        }
    }

    var isAuthenticated: Bool { token != nil }

    func clearSession() {
        token = nil
        UserDefaults.standard.removeObject(forKey: "saved_user")
    }

    // MARK: HTTP verbs

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET", body: nil)
    }

    func post<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "POST", body: nil)
    }

    func postJSON<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(path, method: "POST", body: try JSONEncoder().encode(body))
    }

    func putJSON<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(path, method: "PUT", body: try JSONEncoder().encode(body))
    }

    func patchJSON<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await send(path, method: "PATCH", body: try JSONEncoder().encode(body))
    }

    func delete(_ path: String) async throws {
        let _: ApiMessage = try await send(path, method: "DELETE", body: nil)
    }

    // MARK: Core

    private func send<T: Decodable>(_ path: String, method: String, body: Data?) async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(path)") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 401 {
            clearSession()
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(ApiMessage.self, from: data))?.message
                ?? "Error \(http.statusCode)"
            throw APIError.serverError(msg)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}
