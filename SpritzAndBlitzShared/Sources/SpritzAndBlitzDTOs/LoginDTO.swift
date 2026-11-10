public struct LoginDTO: Codable, Sendable, Equatable {
    public let sessionToken: String

    public init(sessionToken: String) {
        self.sessionToken = sessionToken
    }
}
