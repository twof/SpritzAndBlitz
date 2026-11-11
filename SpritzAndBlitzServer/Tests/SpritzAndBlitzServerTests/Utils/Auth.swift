@testable import SpritzAndBlitzServer

import Crypto
import FluentKit
import Foundation
import Vapor
import HTTPTypes

func sessionToken(forUserNamed name: String, on db: any Database) async throws -> String {
    guard let user = try await User.query(on: db).filter(\.$name == name).first() else {
        throw Abort(.notFound)
    }
    let raw = SymmetricKey(size: .bits256).withUnsafeBytes(Data.init)
    try await UserToken(
        userId: user.requireID(),
        token: hashSessionToken(raw),
        expiresAt: Date().addingTimeInterval(3600)
    ).save(on: db)
    return raw.base64EncodedString()
}

