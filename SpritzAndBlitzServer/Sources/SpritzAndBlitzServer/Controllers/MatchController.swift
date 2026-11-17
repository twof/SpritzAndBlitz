import FluentKit
import SpritzAndBlitzDTOs
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
        
        guard let mostRecentUncompletedMatch else {
            throw Abort(.notFound)
        }
        
        return try await mostRecentUncompletedMatch.matchDTO(database: databases.database())
    }
    
    func status(_ req: Request) async throws -> MatchDTO {
        guard
            let matchId = req.parameters.get("id"),
            let matchUUID = UUID(uuidString: matchId)
        else { throw Abort(.internalServerError) }
        guard let match = try await Match.find(matchUUID, on: databases.database()) else {
            throw Abort(.notFound)
        }
        
        return try await match.matchDTO(database: databases.database())
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
            let lastRoundId = try await match.lastRoundId(database: databases.database())
        else {
            throw Abort(.internalServerError)
        }
        
        guard let lastRound = try await match.lastRound(database: databases.database()) else {
            throw Abort(.internalServerError)
        }
        
        guard !lastRound.scores.contains(where: { $0.user.name == user.name }) else {
            throw Abort(.badRequest)
        }
        
        let newScore = try UserRoundScore(
            roundId: lastRoundId,
            userId: user.requireID(),
            score: score.score,
            didBlitz: score.didBlitz
        )
        try await newScore.save(on: databases.database())
        
        if try await match.isLastRoundCompleted(database: databases.database()) {
            // Check for completion of the match
            let scores = try await match.totalScore(database: databases.database())
            
            if scores.winner() != nil {
                match.isComplete = true
                try await match.save(on: databases.database())
            } else {
                let newRound = try Round(date: Date(), matchId: match.requireID())
                try await newRound.save(on: databases.database())
            }
        }
        
        return try await match.matchDTO(database: databases.database())
    }
}

extension Match {
    func userCount(database: any Database) async throws -> Int {
        try await self.$users.get(on: database).count
    }
    
    func matchDTO(database: any Database) async throws -> MatchDTO {
        let scores = try await totalScore(database: database)
        let lastCompletedRound = try await lastCompletedRound(database: database)
        let currentRoundScores = try await lastRound(database: database).map { round in
            round.scores.map { score in
                MatchDTO.UserMatchStatus(name: score.user.name, score: score.score)
            }
        }
        
        return try MatchDTO(
            id: requireID(),
            currentRound: currentRoundScores ?? [],
            totals: scores,
            lastRound: lastCompletedRound?.scores
                .map { MatchDTO.UserMatchStatus(name: $0.user.name, score: $0.score) },
            winner: scores.winner()
        )
    }
    
    func isLastRoundCompleted(database: any Database) async throws -> Bool {
        let loadedLastRound = try await lastRound(database: database)
        let userCount = try await userCount(database: database)
        
        return loadedLastRound.map { $0.scores.count == userCount } ?? true
    }
    
    func lastRoundId(database: any Database) async throws -> UUID? {
        try await $rounds.get(on: database).last?.id
    }
    
    func lastRound(database: any Database) async throws -> Round? {
        let rounds = try await self.$rounds.query(on: database)
            .with(\.$scores) { $0.with(\.$user) }
            .all()
        
        return rounds.sorted { left, right in
            left.date < right.date
        }.last
    }
    
    func lastCompletedRound(database: any Database) async throws -> Round? {
        let userCount = try await userCount(database: database)
        let rounds = try await $rounds
            .query(on: database)
            .with(\.$scores) { $0.with(\.$user) }
            .sort(\.$date)
            .all()
        
        let lastCompleteRound = rounds.filter {
            userCount == $0.scores.count
        }.last
        
        return lastCompleteRound
    }
}

extension Array where Element == MatchDTO.UserMatchStatus {
    func winner() -> MatchDTO.UserMatchStatus? {
        let sorted = self.sorted(by: { left, right in
            left.score < right.score
        })
        let highestTwo = Array(sorted.suffix(2))
        
        let isTied = highestTwo.count == 2 && highestTwo[0] == highestTwo[1]
        
        // Game continues until there is no tie
        if isTied { return nil }
                
        guard let max = highestTwo.last else { return nil }
        
        return max.score >= 75 ? max : nil
    }
}
