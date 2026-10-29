import FluentKit

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class User: Model, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    /// Scrypt hash in the format `$scrypt$ln=17,r=8,p=1$<salt b64>$<hash b64>`
    @Field(key: "password")
    var password: String
    
    @Siblings(through: UserMatch.self, from: \.$user, to: \.$match)
    var matches: [Match]
    
    @Siblings(through: UserLobby.self, from: \.$user, to: \.$lobby)
    var lobbies: [Lobby]
    
    @Children(for: \UserRoundScore.$user)
    var scores: [UserRoundScore]
    
    init() { }
    
    init(id: UUID? = nil, name: String, password: String) {
        self.id = id
        self.name = name
        self.password = password
    }
    
    func toDTO() -> UserDTO? {
        guard let name = self.$name.value else { return nil }
        return .init(
            id: self.id,
            name: name
        )
    }
}
