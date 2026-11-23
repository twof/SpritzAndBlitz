import Dependencies
import DependenciesMacros
import SpritzAndBlitzDTOs
import Foundation

nonisolated extension DependencyValues {
    @DependencyEntry
    var getMatchStatusClient: @Sendable (AuthedClient, UUID) async throws -> MatchDTO = { authedClient, matchId in
        let data = try await authedClient
            .authedGet(URL(string: "http://localhost:8080/match/\(matchId.uuidString)/status")!)
        return try JSONDecoder().decode(MatchDTO.self, from: data)
    }
}
