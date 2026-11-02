import FluentKit
import Foundation

#if canImport(FoundationEssentials)
import struct FoundationEssentials.UUID
#else
import struct Foundation.UUID
#endif

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Match: Model, @unchecked Sendable {
    static let schema = "matches"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "date")
    var date: Date
    
    @Field(key: "is_complete")
    var isComplete: Bool
    
    @Children(for: \Round.$match)
    var rounds: [Round]
    
    @Siblings(through: UserMatch.self, from: \.$match, to: \.$user)
    var users: [User]
    
    init() { }
    
    init(id: UUID? = nil, date: Date) {
        self.id = id
        self.date = date
        self.rounds = [Round()]
    }
    
    func totalScore() -> [String: Int] {
        let rounds = self.$rounds.wrappedValue
        var results = [String: Int]()
        for round in rounds {
            let scores = round.$scores.wrappedValue
            for score in scores {
                results[score.$user.name, default: 0] += score.score
            }
        }
        
        return results
    }
}
