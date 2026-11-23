import FluentKit
import FluentSQL

struct AddMatchRelationToLobby: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("matches")
            .field("lobby_id", .uuid, .required, .references("lobbies", "id", onDelete: .cascade))
            .unique(on: "lobby_id")
            .update()
    }
    func revert(on database: any Database) async throws {
        try await database.schema("matches").deleteField("lobby_id").update()
    }
}
