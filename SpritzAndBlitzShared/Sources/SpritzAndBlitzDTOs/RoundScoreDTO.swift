public struct RoundScoreDTO: Codable, Sendable, Equatable {
    public var score: Int
    public var didBlitz: Bool

    public init(score: Int, didBlitz: Bool) {
        self.score = score
        self.didBlitz = didBlitz
    }
}
