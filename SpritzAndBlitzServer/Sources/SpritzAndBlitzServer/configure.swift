import NIOSSL
import FluentKit
import FluentPostgresDriver
import Vapor
import Configuration

func defaultDatabasesConfig(configReader: ConfigReader) throws -> Databases {
    let databases = Databases(threadPool: .singleton, on: .singletonMultiThreadedEventLoopGroup)
    
    databases.use(
        DatabaseConfigurationFactory.postgres(
            configuration: .init(
                hostname: configReader.string(forKey: "DATABASE_HOST")!,
                port: configReader.int(forKey: "DATABASE_PORT")!,
                username: configReader.string(forKey: "DATABASE_USERNAME")!,
                password: configReader.string(forKey: "DATABASE_PASSWORD")!,
                database: configReader.string(forKey: "DATABASE_NAME"),
                tls: .prefer(try .init(configuration: .clientDefault))
            )
        ),
        as: .psql
    )
    
    return databases
}

/// configures your application
func configure(_ app: Application, configuredDatabases: Databases? = nil) async throws {
    let configuredDatabases = try configuredDatabases ?? defaultDatabasesConfig(
        configReader: app.configReader
    )
    // close database connections cleanly on shutdown
    app.addService(configuredDatabases)

    // run migrations before the app boots
    app.addLifecycleHandler(
        MigrateLifecycleHandler(
            databases: configuredDatabases,
            migrations:
                CreateLobby(),
                CreateMatch(),
                CreateRound(),
                CreateUser(),
                CreateUserLobby(),
                CreateUserMatch(),
                CreateUserRoundScore(),
                CreateUserTokens(),
        )
    )

    // register routes
    try await routes(app, databases: configuredDatabases)
}
