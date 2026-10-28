import FluentKit

struct CreateUserMatch: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_matches")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .foreignKey("user_id", references: "users", "id")
            .field("match", .uuid, .required, .references("matches", "id", onDelete: .cascade))
            .foreignKey("match_id", references: "matches", "id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_matches").delete()
    }
}
