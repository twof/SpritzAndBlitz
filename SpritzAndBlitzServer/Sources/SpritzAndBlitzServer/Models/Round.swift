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
final class Round: Model, @unchecked Sendable {
    static let schema = "rounds"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "date")
    var date: Date
    
    @Parent(key: "match_id")
    var match: Match
    
    @Children(for: \UserRoundScore.$round)
    var scores: [UserRoundScore]
    
    init() { }
    
    init(id: UUID? = nil, date: Date, matchId: Match.IDValue) {
        self.id = id
        self.date = date
        self.$match.id = matchId
    }
}
