import FluentKit
import Foundation

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class UserRoundScore: Model, @unchecked Sendable {
    static let schema = "user_round_scores"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "round_id")
    var round: Round
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "score")
    var score: Int
    
    @Field(key: "did_blitz")
    var didBlitz: Bool
    
    init() { }
    
    init(
        id: UUID? = nil,
        roundId: Round.IDValue,
        userId: User.IDValue,
        score: Int,
        didBlitz: Bool
    ) {
        self.id = id
        self.$round.id = roundId
        self.$user.id = userId
        self.score = score
        self.didBlitz = didBlitz
    }
}
