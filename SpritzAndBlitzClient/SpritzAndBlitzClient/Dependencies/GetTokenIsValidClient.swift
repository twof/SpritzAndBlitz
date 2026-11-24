import Dependencies
import DependenciesMacros
import SpritzAndBlitzDTOs
import Foundation

nonisolated extension DependencyValues {
    @DependencyEntry
    var getTokenIsValidClient: @Sendable (AuthedClient) async throws -> Bool = { authedClient in
        do {
            _ = try await authedClient
                .authedGet(API.url("validate_token"))
            return true
        } catch {
            return false
        }
    }
}
