import FluentKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct SignupDTO: Content {
    var name: String
    var password: String
}
