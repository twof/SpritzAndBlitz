import Foundation

struct AuthedClient: Equatable, Hashable, Sendable {
    let sessionToken: String
    let playerName: String
    
    func authedGet(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws(AuthedClientError) -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"
        
        for header in headers {
            request.setValue(header.key, forHTTPHeaderField: header.value)
        }
        
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "authorization")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .urlSessionError(error)
        }
         
        guard let response = response as? HTTPURLResponse else {
            throw .unknownResponse
        }
        
        if response.statusCode != 200 {
            throw .urlStatus(response.statusCode)
        }
        
        return data
    }
    
    func authedPost(
        _ url: URL,
        headers: [String: String] = [:]
    ) async throws(AuthedClientError) -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        for header in headers {
            request.setValue(header.key, forHTTPHeaderField: header.value)
        }
        
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "authorization")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .urlSessionError(error)
        }
        
        guard let response = response as? HTTPURLResponse else {
            throw .unknownResponse
        }
        
        if response.statusCode != 200 {
            throw .urlStatus(response.statusCode)
        }
        
        return data
    }
    
    func authedPost<T>(
        _ url: URL,
        content: T,
        headers: [String: String] = [:]
    ) async throws(AuthedClientError) -> Data where T: Encodable {
        let encodedContent: Data
        do {
            encodedContent = try JSONEncoder().encode(content)
        } catch {
            throw .encoder(error)
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        for header in headers {
            request.setValue(header.key, forHTTPHeaderField: header.value)
        }
        
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "authorization")
        request.httpBody = encodedContent
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .urlSessionError(error)
        }
        
        guard let response = response as? HTTPURLResponse else {
            throw .unknownResponse
        }
        
        if response.statusCode != 200 {
            throw .urlStatus(response.statusCode)
        }
        
        return data
    }
    
    enum AuthedClientError: Error {
        case unknownResponse
        case urlSessionError(Error)
        case urlStatus(Int)
        case encoder(Error)
    }
}
