#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct MatchDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let users: [UserMatchStatus]
    public let lastRound: [UserMatchStatus]?
    public let winner: UserMatchStatus?

    public init(id: UUID, users: [UserMatchStatus], lastRound: [UserMatchStatus]?, winner: UserMatchStatus?) {
        self.id = id
        self.users = users
        self.lastRound = lastRound
        self.winner = winner
    }
}

extension MatchDTO {
    public struct UserMatchStatus: Codable, Sendable, Equatable {
        public let name: String
        public let score: Int

        public init(name: String, score: Int) {
            self.name = name
            self.score = score
        }
    }
}
