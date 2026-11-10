#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct UserDTO: Codable, Sendable, Equatable {
    public var id: UUID?
    public var name: String

    public init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
