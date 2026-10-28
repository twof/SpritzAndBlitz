import FluentKit

struct CreateRound: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("rounds")
            .id()
            .field("date", .datetime, .required)
            .field("match_id", .uuid, .required, .references("matches", "id", onDelete: .cascade))
            .foreignKey("match_id", references: "matches", "id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("rounds").delete()
    }
}
