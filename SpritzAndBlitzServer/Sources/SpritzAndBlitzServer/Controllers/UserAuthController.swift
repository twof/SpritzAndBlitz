import FluentKit
import HTTPTypes
import RoutingKit
import Vapor
import Crypto
import CryptoExtras

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct UserAuthController: RouteCollection {
    let databases: Databases
    
    init(databases: Databases) {
        self.databases = databases
    }
    
    func boot(routes: any RoutesBuilder) throws {
        routes.post("signup", use: self.signup)
        routes.post("login", use: self.login)
    }
    
    func signup(_ req: Request) async throws -> LoginDTO {
        let body = try await req.content.decode(SignupDTO.self)
        
        // Does user exist
        let userExists = try await User.query(on: databases.database()).filter(\.$name, .equal, body.name).first() != nil
        guard !userExists else { throw Abort(.badRequest) }
        
        // If not create user
        let scrypt = try ScryptHash(password: body.password)
        
        let userAuth = User(name: body.name, password: scrypt.encoded())
        try await userAuth.save(on: databases.database())
        
        let session = try await createNewSession(user: userAuth)
        
        return LoginDTO(sessionToken: session.sessionToken)
    }
    
    func login(_ req: Request) async throws -> LoginDTO {
        let body = try await req.content.decode(SignupDTO.self)
        
        // Does user exist
        let existingUser = try await User.query(on: databases.database()).filter(\.$name, .equal, body.name).first()
        guard let existingUser else { throw Abort(.notFound) }
        
        guard let existingScrypt = ScryptHash(existingUser.password) else {
            throw Abort(.internalServerError)
        }
        
        // password does not match
        guard try existingScrypt.matches(password: body.password) else {
            throw Abort(.unauthorized)
        }
        
        let session = try await createNewSession(user: existingUser)
        
        return LoginDTO(sessionToken: session.sessionToken)
    }
    
    // the saved token is a symetric key which is SHA256 hashed, then base64 encoded to a string
    // Then sent token is base64 encoded but not sha256 hashed
    // Incoming tokens need to be base64 decoded and then sha256 hashed
    private func createNewSession(user: User) async throws -> (UserToken, sessionToken: String) {
        let sessionToken = SymmetricKey(size: .bits256).withUnsafeBytes(Data.init)
        
        let fourteenDaysInSeconds = Double(60 * 60 * 24 * 14)
        let session = try UserToken(
            userId: user.requireID(),
            token: hashSessionToken(sessionToken),
            expiresAt: Date().addingTimeInterval(fourteenDaysInSeconds)
        )
        try await session.save(on: databases.database())
        
        return (session, sessionToken: sessionToken.base64EncodedString())
    }
}

func hashSessionToken(_ token: Data) -> String {
    SHA256.hash(data: token).withUnsafeBytes(Data.init).base64EncodedString()
}

func hashSessionToken(_ token: String) -> String {
    hashSessionToken(token.data(using: .utf8)!)
}

struct ScryptHash {
    var rounds: Int, blockSize: Int, parallelism: Int
    var salt: Data, encodedPassword: Data
    
    func encoded() -> String {
        return "$scrypt$rounds=\(rounds),size=\(blockSize),p=\(parallelism)$\(salt.base64EncodedString())$\(encodedPassword.base64EncodedString())"
        
    }
    
    init(password: String, derivedFrom existing: ScryptHash? = nil) throws {
        let rounds = existing?.rounds ?? 1 << 17
        let blockSize = existing?.blockSize ?? 8
        let parallelism = existing?.parallelism ?? 1
        let salt = existing?.salt ?? SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        let encodedPassword = try KDF.Scrypt
            .deriveKey(
                from: password.data(using: .utf8)!,
                salt: salt,
                outputByteCount: 32,
                rounds: rounds,
                blockSize: blockSize,
                parallelism: parallelism
            )
            .withUnsafeBytes { Data($0) }
        
        (self.rounds, self.blockSize, self.parallelism, self.salt, self.encodedPassword) = (
            rounds,
            blockSize,
            parallelism,
            salt,
            encodedPassword
        )
    }
    
    private init(rounds: Int, blockSize: Int, parallelism: Int, salt: Data, encodedPassword: Data) {
        (self.rounds, self.blockSize, self.parallelism, self.salt, self.encodedPassword) = (
            rounds,
            blockSize,
            parallelism,
            salt,
            encodedPassword
        )
    }
    
    // password -> scypt encoding -> base64 encoding
    // base64 encoding -> scrypt encoding.
    
    /// Takes base64 encoded salts and passwords and decodes them
    init?(_ string: String) {
        // "", "scrypt", "ln=17,r=8,p=1", salt, hash
        let parts = string.split(separator: "$", omittingEmptySubsequences: false)
        guard parts.count == 5, parts[0].isEmpty, parts[1] == "scrypt",
              let salt = Data(base64Encoded: String(parts[3])),
              let hash = Data(base64Encoded: String(parts[4])) else { return nil }
        var params: [Substring: Int] = [:]
        for kv in parts[2].split(separator: ",") {
            let pair = kv.split(separator: "=")
            guard pair.count == 2, let v = Int(pair[1]) else { return nil }
            params[pair[0]] = v
        }
        guard let rounds = params["rounds"], let blockSize = params["size"], let p = params["p"] else { return nil }
        self.init(
            rounds: rounds,
            blockSize: blockSize,
            parallelism: p,
            salt: salt,
            encodedPassword: hash
        )
    }
    
    func matches(password: String) throws -> Bool {
        let expectedHash = try ScryptHash(
            password: password,
            derivedFrom: self
        )
        
        return self.encodedPassword == expectedHash.encodedPassword
    }
}
