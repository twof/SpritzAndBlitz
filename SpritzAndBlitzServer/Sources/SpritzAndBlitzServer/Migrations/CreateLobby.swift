import FluentKit

struct CreateLobby: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("lobbies")
            .id()
            .field("date", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("lobbies").delete()
    }
}
