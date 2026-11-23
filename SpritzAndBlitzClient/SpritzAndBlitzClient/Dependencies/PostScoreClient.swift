import Dependencies
import DependenciesMacros
import SpritzAndBlitzDTOs
import Foundation

nonisolated extension DependencyValues {
    @DependencyEntry
    var postScoreClient: @Sendable (AuthedClient, UUID, RoundScoreDTO) async throws -> MatchDTO = { authedClient, matchId, roundScoreDto in
        let url = URL(string: "http://localhost:8080/match/\(matchId.uuidString)/score")!
        let data = try await authedClient.authedPost(url, content: roundScoreDto)
        return try JSONDecoder().decode(MatchDTO.self, from: data)
    }
}

