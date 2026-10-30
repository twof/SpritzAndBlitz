import FluentKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct LobbyDTO: Content {
    let code: UUID
    let users: [UserLobbyStatus]
}

extension LobbyDTO {
    struct UserLobbyStatus: Content {
        let name: String
    }
}
