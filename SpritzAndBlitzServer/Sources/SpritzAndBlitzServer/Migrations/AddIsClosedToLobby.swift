import FluentKit
import FluentSQL

struct AddIsClosedToLobby: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("lobbies")
            .field("is_closed", .bool, .required, .sql(.default(false)))
            .update()
    }
    func revert(on database: any Database) async throws {
        try await database.schema("lobbies").deleteField("is_closed").update()
    }
}
