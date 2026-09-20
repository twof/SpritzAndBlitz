@testable import SpritzAndBlitzServer
import Testing
import Vapor
import NIOSSL
import FluentKit
import FluentPostgresDriver
@TaskLocal var _application: Application?

var app: Application {
    get throws { try #require(_application) }
}
@TaskLocal var _database: (any Database)?

var database: any Database {
    get throws { try #require(_database) }
}
struct AppTrait: TestTrait, SuiteTrait, TestScoping {
    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable @concurrent () async throws -> Void
    ) async throws {
        let app = try await Application(.testing)

        let databases = Databases(threadPool: .singleton, on: .singletonMultiThreadedEventLoopGroup)
        databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database",
            tls: .prefer(try .init(configuration: .clientDefault)))
        ), as: .psql)

        do {
            try await configure(app)
            try await app.run()
            try await $_database.withValue(databases.database(for: app)) {
                try await $_application.withValue(app) {
                    try await function()
                }
            }
            try await databases.revert(migrations: CreateTodo(), on: app)
            await databases.shutdownAsync()
        } catch {
            try? await databases.revert(migrations: CreateTodo(), on: app)
            await databases.shutdownAsync()
            try? await app.shutdown()
            throw error
        }
        try await app.shutdown()
    }
}

extension Trait where Self == AppTrait {
    static func withApp() -> Self { .init() }
}
