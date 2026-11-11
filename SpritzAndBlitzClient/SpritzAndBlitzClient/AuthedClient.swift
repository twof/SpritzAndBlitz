import Foundation

struct AuthedClient: Equatable, Hashable {
    let sessionToken: String
    
    func authedGet(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"
        
        for header in headers {
            request.setValue(header.key, forHTTPHeaderField: header.value)
        }
        
        request.setValue("authorization", forHTTPHeaderField: "Bearer \(sessionToken)")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return data
    }
    
    func authedPost(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        for header in headers {
            request.setValue(header.key, forHTTPHeaderField: header.value)
        }
        
        request.setValue("authorization", forHTTPHeaderField: "Bearer \(sessionToken)")
        let (data, _) = try await URLSession.shared.data(
            for: request
        )
        
        return data
    }
    
    func authedPost<T>(
        _ url: URL,
        content: T,
        headers: [String: String] = [:]
    ) async throws -> Data where T: Encodable {
        let encodedUser = try JSONEncoder().encode(content)
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        for header in headers {
            request.setValue(header.key, forHTTPHeaderField: header.value)
        }
        
        request.setValue("authorization", forHTTPHeaderField: "Bearer \(sessionToken)")
        request.httpBody = encodedUser
        let (data, _) = try await URLSession.shared.data(
            for: request
        )
        
        return data
    }
}
