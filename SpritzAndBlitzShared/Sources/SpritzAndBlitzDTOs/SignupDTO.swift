public struct SignupDTO: Codable, Sendable, Equatable {
    public var name: String
    public var password: String

    public init(name: String, password: String) {
        self.name = name
        self.password = password
    }
}
