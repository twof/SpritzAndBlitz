import FluentKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct MatchDTO: Content {
    let users: [UserMatchStatus]
}

extension MatchDTO {
    struct UserMatchStatus: Content {
        let name: String
        let score: Int
    }
}
