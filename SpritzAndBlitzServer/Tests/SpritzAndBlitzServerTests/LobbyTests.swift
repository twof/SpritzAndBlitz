@testable import SpritzAndBlitzServer
import SpritzAndBlitzDTOs

import HTTPTypes
import Testing
import Vapor
import VaporTesting
import FluentKit
import Crypto
import Foundation

@Suite("Lobby Tests", .withApp())
struct LobbyTests {
    @Test("Lobby creation")
    func createLobby() async throws {
        try await app.testing { client in
            let res = try await client.authedPost("lobby", authInput: .name("foo"))
            #expect(res.status == .ok)
            
            let content = try await res.content.decode(LobbyDTO.self)
            #expect(content.users.count == 1)
            
            #expect(content.users[0].name == "foo")
        }
    }
    
    @Test("Join lobby")
    func joinLobby() async throws {
        try await createLobby { client, lobby in
            let res = try await client.authedPost(
                "lobby/\(lobby.requireID())/join",
                authInput: .name("foo")
            )
            #expect(res.status == .ok)
            let dto = try await res.content.decode(LobbyDTO.self)
            let expectedNames = ["alice", "foo"]
            let actualNames = dto.users.map(\.name).sorted()
            #expect(actualNames == expectedNames)
            
            // Another user joins
            let anotherRes = try await client.authedPost(
                "lobby/\(lobby.requireID())/join",
                authInput: .name("bar")
            )
            #expect(anotherRes.status == .ok)
            let newDto = try await anotherRes.content.decode(LobbyDTO.self)
            let newExpected = ["alice", "bar", "foo"]
            #expect(newExpected == newDto.users.map(\.name).sorted())
        }
    }
    
    @Test func `joining with an invalid uuid throws error`() async throws {
        try await createLobby { client, lobby in
            let res = try await client.authedPost(
                "lobby/invalid-uuid/join",
                authInput: .name("foo")
            )
            #expect(res.status == .badRequest)
        }
    }
    
    @Test func `joining lobby that doesn't exist throws error`() async throws {
        try await createLobby { client, lobby in
            let res = try await client.authedPost(
                "lobby/\(UUID())/join",
                authInput: .name("foo")
            )
            #expect(res.status == .notFound)
        }
    }
    
    @Test func `rejoin lobby`() async throws {
        let (_, token) = try await authedUser(name: "bob")
        try await formLobby { client, lobby in
            let res = try await client.authedPost(
                "lobby/\(lobby.requireID())/join",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            try await #expect(res.content.decode(LobbyDTO.self).users.count == 4)
            
            let leaveRes = try await client.authedPost(
                "lobby/\(lobby.requireID())/leave",
                authInput: .token(token)
            )
            #expect(leaveRes.status == .ok)
            try await #expect(leaveRes.content.decode(LobbyDTO.self).users.count == 3)
            
            let rejoinRes = try await client.authedPost(
                "lobby/\(lobby.requireID())/join",
                authInput: .token(token)
            )
            #expect(rejoinRes.status == .ok)
            try await #expect(res.content.decode(LobbyDTO.self).users.count == 4)
        }
    }
    
    @Test func `ready up`() async throws {
        let (_, token) = try await authedUser(name: "bob")
        try await formLobby { client, lobby in
            let res = try await client.authedPost(
                "lobby/\(lobby.requireID())/ready",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            let content = try await res.content.decode(MatchDTO.self)
            #expect(content.totals.count == 3)
            
            let statusRes = try await client.authedPost(
                "lobby/\(lobby.requireID())/status",
                authInput: .token(token)
            )
            #expect(statusRes.status == .notFound)
        }
    }
    
    private func createLobby(callback: (any TestClient, Lobby) async throws -> Void) async throws {
        try await app.testing { client in
            let res = try await client.authedPost("lobby", authInput: .name("alice"))
            #expect(res.status == .ok)
            let dto = try await res.content.decode(LobbyDTO.self)
            let lobby = try await #require(Lobby.find(dto.code, on: database))
            try await callback(client, lobby)
        }
    }
    
    private func formLobby(callback: (any TestClient, Lobby) async throws -> Void) async throws {
        try await createLobby { client, lobby in
            let res = try await client.authedPost(
                "lobby/\(lobby.requireID())/join",
                authInput: .name("foo")
            )
            #expect(res.status == .ok)
            let dto = try await res.content.decode(LobbyDTO.self)
            let expectedNames = ["alice", "foo"]
            let actualNames = dto.users.map(\.name).sorted()
            #expect(actualNames == expectedNames)
            
            // Another user joins
            let anotherRes = try await client.authedPost(
                "lobby/\(lobby.requireID())/join",
                authInput: .name("bar")
            )
            #expect(anotherRes.status == .ok)
            let newDto = try await anotherRes.content.decode(LobbyDTO.self)
            let newExpected = ["alice", "bar", "foo"]
            #expect(newExpected == newDto.users.map(\.name).sorted())
            
            try await callback(client, lobby)
        }
    }
}
