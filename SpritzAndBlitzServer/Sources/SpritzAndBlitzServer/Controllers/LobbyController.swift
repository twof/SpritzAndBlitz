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
        lobbyRoutes.get(":id", "status", use: getLobbyStatus(_:))
    }
    
    func createLobby(_ req: Request) async throws -> LobbyDTO {
        guard let user = req.auth.get(User.self) else { throw Abort(.unauthorized) }
        
        // Create new lobby
        let newLobby = Lobby(date: Date())
        try await newLobby.save(on: databases.database())
        
        // Put host into lobby
        let userLobby = try UserLobby(userId: user.requireID(), lobbyId: newLobby.requireID())
        try await userLobby.save(on: databases.database())
        
        return try await LobbyDTO(
            code: newLobby.requireID(),
            users: getUsersInLobby(lobbyId: newLobby.requireID()).map { .init(name: $0.name) }
        )
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
            users: getUsersInLobby(lobbyId: lobbyUUID).map { .init(name: $0.name) }
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
            users: getUsersInLobby(lobbyId: lobbyUUID).map { .init(name: $0.name) }
        )
    }
    
    func readyUp(_ req: Request) async throws -> MatchDTO {
        guard
            let lobbyId = req.parameters.get("id"),
            let lobbyUUID = UUID(uuidString: lobbyId)
        else {
            throw Abort(.internalServerError)
        }
        
        return try await databases.database().transaction { database in
            let allUsers = try await getUsersInLobby(lobbyId: lobbyUUID)
            
            // Create match
            let newMatch = Match(date: Date())
            try await newMatch.save(on: database)
            
            // Create the first round
            let newRound = try Round(date: Date(), matchId: newMatch.requireID())
            try await newRound.save(on: database)
            
            // Put all users from lobby into match
            let newUserMatches = try allUsers.map { user in
                try UserMatch(userId: user.requireID(), matchId: newMatch.requireID())
            }
            try await newUserMatches.create(on: database)
            
            // Delete lobby, will cascade to delete UserLobbies
            try await Lobby
                .query(on: databases.database())
                .filter(\.$id == lobbyUUID)
                .delete()
            
            return try MatchDTO(
                id: newMatch.requireID(),
                currentRound: [],
                totals: allUsers.map { .init(name: $0.name, score: 0) },
                lastRound: nil,
                winner: nil
            )
        }
    }
    
    func getLobbyStatus(_ req: Request) async throws -> LobbyDTO {
        guard
            let lobbyId = req.parameters.get("id"),
            let lobbyUUID = UUID(uuidString: lobbyId)
                else { throw Abort(.internalServerError) }
        
        return try await LobbyDTO(
            code: lobbyUUID,
            users: getUsersInLobby(lobbyId: lobbyUUID).map { .init(name: $0.name) }
        )
    }
    
    private func getUsersInLobby(lobbyId: UUID) async throws -> [User] {
        try await User
            .query(on: databases.database())
            .join(UserLobby.self, on: \User.$id == \UserLobby.$user.$id)
            .filter(UserLobby.self, \.$lobby.$id == lobbyId)
            .all()
    }
}
