import FluentKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct LoginDTO: Content {
    let sessionToken: String
}
