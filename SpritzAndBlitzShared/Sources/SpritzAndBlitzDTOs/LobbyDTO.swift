#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct LobbyDTO: Codable, Sendable, Equatable, Hashable {
    public let code: UUID
    public let users: [UserLobbyStatus]
    public let match: MatchDTO?

    public init(code: UUID, users: [UserLobbyStatus], match: MatchDTO?) {
        self.code = code
        self.users = users
        self.match = match
    }
}

extension LobbyDTO {
    public struct UserLobbyStatus: Codable, Sendable, Equatable, Hashable, Identifiable {
        public var id: String { name }
        public let name: String

        public init(name: String) {
            self.name = name
        }
    }
}
