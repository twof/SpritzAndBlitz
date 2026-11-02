import FluentKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct RoundScoreDTO: Content {
    var score: Int
    var didBlitz: Bool
}
