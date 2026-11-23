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

struct LobbyController: RouteCollection {
    let databases: Databases
    
    init(databases: Databases) {
        self.databases = databases
    }
    
    func boot(routes: any RoutesBuilder) throws {
        let lobbyRoutes = routes.grouped("lobby")
        lobbyRoutes.post(use: createLobby(_:))
        lobbyRoutes.post(":id", "join", use: joinLobby(_:))
        lobbyRoutes.post(":id", "leave", use: leaveLobby(_:))
        lobbyRoutes.post(":id", "ready", use: readyUp(_:))
        lobbyRoutes.get(":id", "status", use: getLobbyStatus)
    }
    
    func createLobby(_ req: Request) async throws -> LobbyDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        
        do {
            // Create new lobby
            let newLobby = Lobby(date: Date())
            try await newLobby.save(on: databases.database())
            
            // Put host into lobby
            let userLobby = try UserLobby(userId: user.requireID(), lobbyId: newLobby.requireID())
            try await userLobby.save(on: databases.database())
            
            return try await LobbyDTO(
                code: newLobby.requireID(),
                users: getUsersInLobby(lobbyId: newLobby.requireID(), db: databases.database())
                    .map { .init(name: $0.name) },
                match: nil
            )
        } catch {
            print(error)
            throw error
        }
    }
    
    func joinLobby(_ req: Request) async throws -> LobbyDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        guard
            let lobbyId = req.parameters.get("id"),
            let lobbyUUID = UUID(uuidString: lobbyId)
        else { throw Abort(.badRequest) }
        
        // Ensure lobby exists
        let lobbyExists = try await Lobby
            .query(on: databases.database())
            .filter(\.$id == lobbyUUID).first() != nil
        guard lobbyExists else {
            throw Abort(.notFound)
        }
        
        // Put user into lobby
        let userLobby = try UserLobby(userId: user.requireID(), lobbyId: lobbyUUID)
        try await userLobby.save(on: databases.database())
        
        return try await LobbyDTO(
            code: lobbyUUID,
            users: getUsersInLobby(lobbyId: lobbyUUID, db: databases.database())
                .map { .init(name: $0.name) },
            match: nil
        )
    }
    
    func leaveLobby(_ req: Request) async throws -> LobbyDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        guard
            let lobbyId = req.parameters.get("id"),
            let lobbyUUID = UUID(uuidString: lobbyId)
        else { throw Abort(.internalServerError) }
        
        // Delete user from lobby
        try await UserLobby
            .query(on: databases.database())
            .filter(\.$user.$id == user.requireID())
            .filter(\.$lobby.$id == lobbyUUID)
            .delete()
        
        return try await LobbyDTO(
            code: lobbyUUID,
            users: getUsersInLobby(lobbyId: lobbyUUID, db: databases.database())
                .map { .init(name: $0.name) },
            match: nil
        )
    }
    
    func readyUp(_ req: Request) async throws -> MatchDTO {
        guard
            let lobbyId = req.parameters.get("id"),
            let lobbyUUID = UUID(uuidString: lobbyId)
        else {
            throw Abort(.internalServerError)
        }
        
        // We're going to try to create a match. It may fail due to a constraint error
        // if two users attempt to ready up at the same time and a match already exists
        // for a lobby. In that case we will recover by returning the existing match
        // and a 200.
        do {
            return try await databases.database().transaction { transaction in
                guard
                    let associatedLobby = try await Lobby.find(lobbyUUID, on: transaction)
                        else {
                    throw Abort(.notFound)
                }
                
                let allUsers = try await getUsersInLobby(lobbyId: lobbyUUID, db: transaction)
                
                // Create match
                let newMatch = Match(lobbyId: lobbyUUID, date: Date())
                try await newMatch.save(on: transaction)
                
                // Create the first round
                let newRound = try Round(date: Date(), matchId: newMatch.requireID())
                try await newRound.save(on: transaction)
                
                // Put all users from lobby into match
                let newUserMatches = try allUsers.map { user in
                    try UserMatch(userId: user.requireID(), matchId: newMatch.requireID())
                }
                try await newUserMatches.create(on: transaction)
                
                // Mark lobby closed
                associatedLobby.isClosed = true
                try await associatedLobby.save(on: transaction)
                
                return try MatchDTO(
                    id: newMatch.requireID(),
                    roundNumber: 1,
                    currentRound: [],
                    totals: allUsers.map { .init(name: $0.name, score: 0) },
                    lastRound: nil,
                    winner: nil
                )
            }
        } catch let error as any DatabaseError where error.isConstraintFailure {
            guard let existingMatch = try await getMatchForLobby(
                lobbyId: lobbyUUID,
                db: databases.database()
            )?
                .matchDTO(database: databases.database())
            else {
                throw Abort(.internalServerError, reason: "couldn't find existing match")
            }
            
            return existingMatch
        }
    }
    
    func getLobbyStatus(_ req: Request) async throws -> LobbyDTO {
        guard
            let lobbyId = req.parameters.get("id"),
            let lobbyUUID = UUID(uuidString: lobbyId)
                else { throw Abort(.internalServerError) }
        
        return try await LobbyDTO(
            code: lobbyUUID,
            users: getUsersInLobby(lobbyId: lobbyUUID, db: databases.database())
                .map { .init(name: $0.name) },
            match: getMatchForLobby(lobbyId: lobbyUUID, db: databases.database())?.matchDTO(database: databases.database())
        )
    }
    
    private func getUsersInLobby(lobbyId: UUID, db: any Database) async throws -> [User] {
        try await User
            .query(on: db)
            .join(UserLobby.self, on: \User.$id == \UserLobby.$user.$id)
            .filter(UserLobby.self, \.$lobby.$id == lobbyId)
            .all()
    }
    
    private func getMatchForLobby(lobbyId: UUID, db: any Database) async throws -> Match? {
        try await Lobby.query(on: db)
            .filter(\.$id == lobbyId)
            .with(\.$match)
            .first()?.match
    }
}
