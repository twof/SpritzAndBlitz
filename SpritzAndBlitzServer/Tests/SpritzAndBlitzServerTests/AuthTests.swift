@testable import SpritzAndBlitzServer
import SpritzAndBlitzDTOs

import HTTPTypes
import Testing
import Vapor
import VaporTesting
import FluentKit
import Crypto
import Foundation

@Suite("Auth Tests", .withApp())
struct AuthTests {
    /*
     - user submits username and password
     - user
     */
    @Test("Test Signup Route")
    func signupWorks() async throws {
        let content = SignupDTO(name: "foo", password: "bar")
        
        try await app.testing { client in
            let res = try await client.post("signup", content: content)
            #expect(res.status == .ok)
            
            let allDbUserAuth = try await User.query(on: database).all()
            
            try #require(allDbUserAuth.count == 1)
            let dbUserAuth = allDbUserAuth[0]
            #expect(dbUserAuth.id != nil)
            
            #expect(dbUserAuth.name == content.name)
            let existingPassword = ScryptHash(dbUserAuth.password)!
            try #expect(existingPassword.matches(password: content.password))
            
            let data = try #require(await res.body.data())
            let session = try JSONDecoder().decode(LoginDTO.self, from: data)
            
            #expect(!session.sessionToken.isEmpty)
        }
    }
    
    /*
     - user submits username and password
     - user
     */
    @Test("Signup with existing name fails")
    func signupWithExistingName() async throws {
        let content = SignupDTO(name: "foo", password: "bar")
        
        try await app.testing { client in
            let res = try await client.post("signup", content: content)
            #expect(res.status == .ok)
            
            let secondRes = try await client.post("signup", content: content)
            #expect(secondRes.status == .badRequest)
            
            let allDbUserAuth = try await User.query(on: database).all()
            
            #expect(allDbUserAuth.count == 1)
            let dbUserAuth = allDbUserAuth[0]
            #expect(dbUserAuth.id != nil)
            
            #expect(dbUserAuth.name == content.name)
            let existingPassword = ScryptHash(dbUserAuth.password)!
            try #expect(existingPassword.matches(password: content.password))
        }
    }
    
    /*
     - User submits username and password
     - They receive a session key with a TTL and a refresh token
     - All other requests must use a session key
     - Password is stored encrypted
     */
    @Test("Test Login Route")
    func login() async throws {
        let content = SignupDTO(name: "foo", password: "bar")
        try await signup(username: "foo", password: "bar") { client, _ in
            let res = try await client.post("login", content: content)
            #expect(res.status == .ok)
            
            let data = try #require(await res.body.data())
            let session = try JSONDecoder().decode(LoginDTO.self, from: data)
            
            #expect(!session.sessionToken.isEmpty)
        }
    }
    
    @Test("Test Login Route wrong password")
    func loginWrongPassword() async throws {
        let content = SignupDTO(name: "foo", password: "bar1")
        try await signup(username: "foo", password: "bar") { client, _ in
            let res = try await client.post("login", content: content)
            #expect(res.status == .unauthorized)
        }
    }
    
    @Test("User auth accepts authorized requests")
    func userAuthHappyPath() async throws {
        try await signup(username: "foo", password: "bar") {client, session in
            let tokenHash = try hashSessionToken(
                #require(Data(base64Encoded: session.sessionToken))
            )
            let maybeUserToken = try await UserToken.query(on: database)
                .filter(\.$token == tokenHash)
                .first()
            let userToken = try #require(maybeUserToken)
            let authenticator = try UserAuthenticator(database: database)
            let request = Request()
            try await authenticator
                .authenticate(bearer: .init(token: session.sessionToken), for: request)
            let authedUser = try #require(request.auth.get(User.self))
            try #expect(authedUser.requireID() == userToken.$user.id)
        }
    }
    
    @Test("User auth rejects unauthorized requests")
    func userAuthSadPath() async throws {
        try await signup(username: "foo", password: "bar") { client, session in
            let authenticator = try UserAuthenticator(database: database)
            let request = Request()
            try await authenticator
                .authenticate(bearer: .init(token: "garbagevalue"), for: request) // needs to be valid base64
            #expect(request.auth.get(User.self) == nil)
        }
    }
}

func signup(username: String, password: String, _ body: (any TestClient, LoginDTO) async throws -> Void) async throws {
    let content = SignupDTO(name: username, password: password)
    
    try await app.testing { client in
        let res = try await client.post("signup", content: content)
        let data = try #require(await res.body.data())
        let session = try JSONDecoder().decode(LoginDTO.self, from: data)
        try await body(client, session)
    }
}

func authedUser(name: String = "alice") async throws -> (User, String) {
    let user = User(name: name, password: "unused")   // skip hashing
    try await user.save(on: database)
    let raw = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    let token = UserToken(
        userId: try user.requireID(),
        token: hashSessionToken(raw),
        expiresAt: .now + 3600
    )
    try await token.save(on: database)
    return (user, raw.base64EncodedString())
}

enum AuthInput {
    case name(String)
    case token(String)
}

extension TestClient {
    func authedGet(
        _ url: URI,
        authInput: AuthInput,
        headers: HTTPFields = [:],
        beforeSend: (inout ClientRequest) throws -> Void = { _ in}
    ) async throws -> ClientResponse {
        var headers = headers
        let token = switch authInput {
        case let .name(name): try await authedUser(name: name).1
        case let .token(token): token
        }
        headers[.authorization] = "Bearer \(token)"
        return try await get(url, headers: headers, beforeSend: beforeSend)
    }
    
    func authedPost(
        _ url: URI,
        authInput: AuthInput,
        headers: HTTPFields = [:],
        beforeSend: (inout ClientRequest) throws -> Void = { _ in}
    ) async throws -> ClientResponse {
        var headers = headers
        let token = switch authInput {
        case let .name(name): try await authedUser(name: name).1
        case let .token(token): token
        }
        headers[.authorization] = "Bearer \(token)"
        return try await post(url, headers: headers, beforeSend: beforeSend)
    }
    
    func authedPost<T>(
        _ url: URI,
        authInput: AuthInput,
        content: T,
        headers: HTTPFields = [:]
    ) async throws -> ClientResponse where T: Content {
        var headers = headers
        let token = switch authInput {
        case let .name(name): try await authedUser(name: name).1
        case let .token(token): token
        }
        headers[.authorization] = "Bearer \(token)"
        return try await post(url, headers: headers, content: content)
    }
}
