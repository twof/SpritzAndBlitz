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
final class UserMatch: Model, @unchecked Sendable {
    static let schema = "matches"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "match_id")
    var match: Match
    
    init() { }
    
    init(id: UUID? = nil, userId: User.IDValue, matchId: Match.IDValue) {
        self.id = id
        self.$user.id = userId
        self.$match.id = matchId
    }
}
