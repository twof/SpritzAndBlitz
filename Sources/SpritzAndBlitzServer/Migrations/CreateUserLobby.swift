import FluentKit

struct CreateUserLobby: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_lobbies")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .foreignKey("user_id", references: "users", "id")
            .field("lobby_id", .uuid, .required, .references("lobbies", "id", onDelete: .cascade))
            .foreignKey("lobby_id", references: "lobbies", "id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_lobbies").delete()
    }
}
