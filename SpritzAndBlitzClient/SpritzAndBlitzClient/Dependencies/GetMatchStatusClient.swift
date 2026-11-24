import Dependencies
import DependenciesMacros
import SpritzAndBlitzDTOs
import Foundation

nonisolated extension DependencyValues {
    @DependencyEntry
    var getMatchStatusClient: @Sendable (AuthedClient, UUID) async throws -> MatchDTO = { authedClient, matchId in
        let data = try await authedClient
            .authedGet(API.url("match/\(matchId.uuidString)/status"))
        return try JSONDecoder().decode(MatchDTO.self, from: data)
    }
}
