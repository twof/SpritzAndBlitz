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
final class Lobby: Model, @unchecked Sendable {
    static let schema = "lobbies"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "date")
    var date: Date
    
    @Siblings(through: UserLobby.self, from: \.$lobby, to: \.$user)
    var users: [User]
    
    @OptionalChild(for: \.$lobby)
    var match: Match?
    
    @Field(key: "is_closed")
    var isClosed: Bool
    
    init() { }
    
    init(id: UUID? = nil, date: Date, isClosed: Bool = false) {
        self.id = id
        self.date = date
        self.isClosed = isClosed
    }
}
