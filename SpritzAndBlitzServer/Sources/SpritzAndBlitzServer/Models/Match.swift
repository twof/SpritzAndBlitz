import FluentKit
import SpritzAndBlitzDTOs
import Foundation

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Match: Model, @unchecked Sendable {
    static let schema = "matches"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "date")
    var date: Date

    @Field(key: "is_complete")
    var isComplete: Bool
    
    @Children(for: \Round.$match)
    var rounds: [Round]
    
    @Siblings(through: UserMatch.self, from: \.$match, to: \.$user)
    var users: [User]
    
    init() { }
    
    init(id: UUID? = nil, date: Date, isComplete: Bool = false) {
        self.id = id
        self.date = date
        self.isComplete = isComplete
    }
    
    func totalScore(database: any Database) async throws -> [MatchDTO.UserMatchStatus] {
        let users = try await $users.get(on: database)
        let usersDict = users.reduce(into: [String: Int]()) { $0[$1.name] = 0 }
        let scores = try await UserRoundScore.query(on: database)
            .join(Round.self, on: \UserRoundScore.$round.$id == \Round.$id)
            .join(User.self, on: \UserRoundScore.$user.$id == \User.$id)
            .filter(Round.self, \.$match.$id == requireID())
            .all()
        let totalScores = try scores
            .reduce(into: usersDict) { $0[try $1.joined(User.self).name, default: 0] += $1.score }
        
        return totalScores.map { key, value in
            MatchDTO.UserMatchStatus(name: key, score: value)
        }
    }
}
