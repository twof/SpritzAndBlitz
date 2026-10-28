import FluentKit

struct CreateMatch: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("matches")
            .id()
            .field("date", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("matches").delete()
    }
}
