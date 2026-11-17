#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct LobbyDTO: Codable, Sendable, Equatable, Hashable {
    public let code: UUID
    public let users: [UserLobbyStatus]

    public init(code: UUID, users: [UserLobbyStatus]) {
        self.code = code
        self.users = users
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
