import Vapor
import FluentKit
import Foundation
import HTTPTypes

struct UserAuthenticator: BearerAuthenticator {
    let database: any Database
    
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        guard let base64Decoded = Data(base64Encoded: bearer.token) else {
            throw Abort(.badRequest)
        }
        let tokenHash = hashSessionToken(base64Decoded)
        
        guard let token = try await UserToken.query(on: database)
            .filter(\.$token == tokenHash)
            .filter(\.$expiresAt > Date())
            .with(\.$user)
            .first()
        else { return }
        
        request.auth.login(token.user)
    }
}

extension User: Authenticatable {}
