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
                hostname: configReader.string(forKey: "host", default: "localhost"),
                port: configReader.int(forKey: "port", default: SQLPostgresConfiguration.ianaPortNumber),
                username: configReader.string(forKey: "username", default: "vapor_username"),
                password: configReader.string(forKey: "password", default: "vapor_password"),
                database: configReader.string(forKey: "name", default: "vapor_database"),
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
                CreateUser(),
                CreateUserTokens(),
            CreateMatch(),
            CreateRound(),
            CreateUserMatch(),
            CreateUserRoundScore()
        )
    )

    // register routes
    try await routes(app, databases: configuredDatabases)
}
