import FluentKit
import HTTPTypes
import RoutingKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct MatchController: RouteCollection {
    let databases: Databases
    
    init(databases: Databases) {
        self.databases = databases
    }
    
    func boot(routes: any RoutesBuilder) throws {
        let matchGroup = routes.grouped("match")
        matchGroup.get("current", use: current)
        matchGroup.get(":id", "status", use: status)
        matchGroup.post(":id", "score", use: score)
    }
    
    func current(_ req: Request) async throws -> MatchDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        
        let mostRecentUncompletedMatch = try await user.$matches.query(on: databases.database())
            .filter(\.$isComplete == false)
            .sort(\.$date)
            .first()
        
        guard let mostRecentUncompletedMatch else { throw Abort(.notFound) }
        
        return try matchDTO(model: mostRecentUncompletedMatch)
    }
    
    func status(_ req: Request) async throws -> MatchDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        guard
            let matchId = req.parameters.get("id"),
            let matchUUID = UUID(uuidString: matchId)
        else { throw Abort(.internalServerError) }
        guard let match = try await Match.find(matchUUID, on: databases.database()) else {
            throw Abort(.notFound)
        }
        
        return try matchDTO(model: match)
    }
    
    func score(_ req: Request) async throws -> MatchDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        let score = try await req.content.decode(RoundScoreDTO.self)
        guard
            let matchId = req.parameters.get("id"),
            let matchUUID = UUID(uuidString: matchId)
        else { throw Abort(.internalServerError) }
        guard let match = try await Match.find(matchUUID, on: databases.database()) else {
            throw Abort(.notFound)
        }
        
        // We expect a round to have been created when the match was created
        // We also expect a new round to be created upon completion of the previous round
        guard
            let lastRoundId = match.lastRoundId(),
            !match.lastRoundCompleted()
        else {
            throw Abort(.internalServerError)
        }
        
        let newScore = try UserRoundScore(
            roundId: lastRoundId,
            userId: user.requireID(),
            score: score.score,
            didBlitz: score.didBlitz
        )
        try await newScore.save(on: databases.database())
        
        // Refetch match
        guard let match = try await Match.find(matchUUID, on: databases.database()) else {
            throw Abort(.notFound)
        }
        
        if match.lastRoundCompleted() {
            // Check for completion of the match
            let scores = match.totalScore()
            
            if scores.values.reduce(false, { $0 || $1 >= 75 }) {
                match.isComplete = true
                try await match.save(on: databases.database())
            } else {
                let newRound = try Round(date: Date(), matchId: match.requireID())
                try await newRound.save(on: databases.database())
            }
        }
        
        return try matchDTO(model: match)
    }
    
    private func matchDTO(model: Match) throws -> MatchDTO {
        let scores = model.totalScore()
        let lastRound = model.lastRoundScores()
        
        return try MatchDTO(
            id: model.requireID(),
            users: scores.keys.map { MatchDTO.UserMatchStatus(name: $0, score: scores[$0]!) },
            lastRound: lastRound.keys
                .map { MatchDTO.UserMatchStatus(name: $0, score: lastRound[$0]!) }
        )
    }
}

extension Match {
    func lastRoundCompleted() -> Bool {
        let userCount = self.users.count
        return lastRoundScores().count == userCount
    }
    
    func lastRoundId() -> UUID? {
        return rounds.last?.id
    }
    
    func lastRoundScores() -> [String: Int] {
        var scores = [String: Int]()
        guard let round  = self.rounds.last else {
            return [:]
        }
        
        for score in round.scores {
            scores[score.user.name] = score.score
        }
        
        return scores
    }
}
