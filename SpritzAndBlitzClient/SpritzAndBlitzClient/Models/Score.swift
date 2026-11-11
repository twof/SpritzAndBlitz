import Foundation

struct Score: Codable {
    let id: UUID?
    let userId: UUID
    let round: String
    let table: String
    let score: Int
}
