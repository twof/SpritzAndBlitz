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
struct MatchTests {
    @Test func `get current match exists`() async throws {
        try await startLobby { client, match in
            let token = try await sessionToken(forUserNamed: "foo", on: database)
            let res = try await client.authedGet(
                "match/current",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            let matchDto = try await res.content.decode(MatchDTO.self)
            #expect(matchDto.users.count == 3)
            #expect(matchDto.lastRound == nil)
            #expect(matchDto.users.map { $0.score }.reduce(0, +) == 0)
        }
    }
    
    @Test func `get current match status`() async throws {
        try await startLobby { client, match in
            let token = try await sessionToken(forUserNamed: "foo", on: database)
            let res = try await client.authedGet(
                "match/current",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            let matchDto = try await res.content.decode(MatchDTO.self)
            
            let statusRes = try await client.authedGet(
                "match/\(matchDto.id)/status",
                authInput: .token(token)
            )
            #expect(statusRes.status == .ok)
            let statusMatchDto = try await res.content.decode(MatchDTO.self)
            #expect(statusMatchDto.users.count == 3)
            #expect(statusMatchDto.lastRound == nil)
            #expect(statusMatchDto.users.map { $0.score }.reduce(0, +) == 0)
        }
    }
    
    @Test func `score current match`() async throws {
        try await startLobby { client, match in
            let token = try await sessionToken(forUserNamed: "foo", on: database)
            let res = try await client.authedGet(
                "match/current",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            let matchDto = try await res.content.decode(MatchDTO.self)
            
            let score = RoundScoreDTO(score: 10, didBlitz: true)
            let scoreRes = try await client.authedPost(
                "match/\(matchDto.id)/score",
                authInput: .token(token),
                content: score
            )
            #expect(scoreRes.status == .ok)
            let scoreMatchDto = try await scoreRes.content.decode(MatchDTO.self)
            #expect(scoreMatchDto.users.count == 3)
            #expect(scoreMatchDto.lastRound == nil)
            #expect(scoreMatchDto.users.map { $0.score }.reduce(0, +) == 10)
            let fooScore = try #require(scoreMatchDto.users.first { $0.name == "foo" })
            #expect(fooScore.score == 10)
            
            let statusRes = try await client.authedGet(
                "match/\(matchDto.id)/status",
                authInput: .token(token)
            )
            #expect(statusRes.status == .ok)
            let statusMatchDto = try await statusRes.content.decode(MatchDTO.self)
            #expect(statusMatchDto.users.count == 3)
            #expect(statusMatchDto.lastRound == nil)
            #expect(statusMatchDto.users.map { $0.score }.reduce(0, +) == 10)
            let fooStatusScore = try #require(statusMatchDto.users.first { $0.name == "foo" })
            #expect(fooStatusScore.score == 10)
        }
    }
    
    @Test func `win current match`() async throws {
        try await startLobby { client, match in
            let token = try await sessionToken(forUserNamed: "foo", on: database)
            let res = try await client.authedGet(
                "match/current",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            let matchDto = try await res.content.decode(MatchDTO.self)
            
            let score = RoundScoreDTO(score: 75, didBlitz: true)
            let scoreRes = try await client.authedPost(
                "match/\(matchDto.id)/score",
                authInput: .token(token),
                content: score
            )
            #expect(scoreRes.status == .ok)
            
            // Need to have other users score as well
            let aliceToken = try await sessionToken(forUserNamed: "alice", on: database)
            let barToken = try await sessionToken(forUserNamed: "bar", on: database)
            for token in [aliceToken, barToken] {
                let score = RoundScoreDTO(score: 10, didBlitz: true)
                let scoreRes = try await client.authedPost(
                    "match/\(matchDto.id)/score",
                    authInput: .token(token),
                    content: score
                )
                #expect(scoreRes.status == .ok)
            }
            
            let statusRes = try await client.authedGet(
                "match/\(matchDto.id)/status",
                authInput: .token(token)
            )
            #expect(statusRes.status == .ok)
            let statusMatchDto = try await statusRes.content.decode(MatchDTO.self)
            #expect(statusMatchDto.users.count == 3)
            #expect(statusMatchDto.lastRound == [
                .init(name: "foo", score: 75),
                .init(name: "alice", score: 10),
                .init(name: "bar", score: 10)
            ])
            #expect(statusMatchDto.users.map { $0.score }.reduce(0, +) == 95)
            let fooStatusScore = try #require(statusMatchDto.users.first { $0.name == "foo" })
            #expect(fooStatusScore.score == 75)
            #expect(statusMatchDto.winner == MatchDTO.UserMatchStatus(name: "foo", score: 75))
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
    
    private func startLobby(callback: (any TestClient, Match) async throws -> Void) async throws {
        try await formLobby { client, lobby in
            let token = try await sessionToken(forUserNamed: "foo", on: database)
            let res = try await client.authedPost(
                "lobby/\(lobby.requireID())/ready",
                authInput: .token(token)
            )
            #expect(res.status == .ok)
            let matchDto = try await res.content.decode(MatchDTO.self)
            let match = try await #require(Match.find(matchDto.id, on: database))
            
            try await callback(client, match)
        }
    }
}
