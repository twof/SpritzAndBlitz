@testable import SpritzAndBlitzServer
import Foundation
import Testing
import Vapor
import NIOSSL
import FluentKit
import FluentPostgresDriver
import Configuration
import SystemPackage

actor Counter {
    var current = 8080
    
    func getCount() -> Int {
        let current = current
        self.current += 1
        return current
    }
}

@TaskLocal var _application: Application?

var app: Application {
    get throws { try #require(_application) }
}
@TaskLocal var _database: (any Database)?

var database: any Database {
    get throws { try #require(_database) }
}
let counter = Counter()
struct AppTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }
    
    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable @concurrent () async throws -> Void
    ) async throws {
        guard !test.isSuite else { return try await function() }  // only per-test
        let envPath = String(#filePath.split(separator: "/Tests/")[0]) + "/test.env"
        let filePath = FilePath(envPath)
        let app = try await Application(
            .testing,
            configReader: .init(
                providers: [
                    CommandLineArgumentsProvider(),
                    EnvironmentVariablesProvider(
                        environmentFilePath: filePath
                    )
                ]
            )
        )
        
        
        let configReader = app.configReader

        let databases = Databases(threadPool: .singleton, on: .singletonMultiThreadedEventLoopGroup)
        var dbConfig = SQLPostgresConfiguration(
            hostname: configReader.string(forKey: "DATABASE_HOST")!,
            port: configReader.int(forKey: "DATABASE_PORT")!,
            username: configReader.string(forKey: "DATABASE_USERNAME")!,
            password: configReader.string(forKey: "DATABASE_PASSWORD")!,
            database: configReader.string(forKey: "DATABASE_NAME")!,
            tls: .prefer(try .init(configuration: .clientDefault))
        )
        let schema = "test_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        dbConfig.searchPath = [schema]
        databases.use(.postgres(configuration: dbConfig),as: .psql)
        
        let sql = try #require(try databases.database() as? any SQLDatabase)
        try await sql.raw("CREATE SCHEMA \(ident: schema)").run()

        do {
            try await configure(app, configuredDatabases: databases)
            try await app.boot()
//            app.serverConfiguration.port = await counter.getCount()
//            try await app.run()
            try await $_database.withValue(try databases.database()) {
                try await $_application.withValue(app) {
                    try await function()
                }
            }
            try await sql.raw("DROP SCHEMA \(ident: schema) CASCADE").run()
            await databases.shutdownAsync()
        } catch {
            Issue.record("\(String(reflecting: error))")
            try await sql.raw("DROP SCHEMA \(ident: schema) CASCADE").run()
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
