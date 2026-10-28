import FluentKit

struct CreateUserRoundScore: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_round_score")
            .id()
            .field("round_id", .uuid, .required, .references("rounds", "id", onDelete: .cascade))
            .foreignKey("round_id", references: "rounds", "id")
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .foreignKey("user_id", references: "users", "id")
            .field("score", .int64, .required)
            .field("did_blitz", .bool, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_round_score").delete()
    }
}
