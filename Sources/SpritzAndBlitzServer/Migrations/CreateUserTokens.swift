import FluentKit

struct CreateUserTokens: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_tokens")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .foreignKey("user_id", references: "users", "id")
            .field("token", .string, .required).unique(on: "token")
            .field("expires_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_tokens").delete()
    }
}
