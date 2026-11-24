import Dependencies
import DependenciesMacros
import SpritzAndBlitzDTOs
import Foundation
import KeychainSwift

@DependencyClient
nonisolated struct KeychainClient: Sendable {
    var set: @Sendable (_ value: String, _ forKey: String) -> Void 
    var get: @Sendable (_ key: String) -> String?
}

nonisolated extension KeychainClient: DependencyKey {
    static let liveValue = KeychainClient(
        set: { value, key in
            KeychainSwift().set(value, forKey: key)
        }, get: { key in
            KeychainSwift().get(key)
        }
    )
}

nonisolated extension DependencyValues {
    var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}
