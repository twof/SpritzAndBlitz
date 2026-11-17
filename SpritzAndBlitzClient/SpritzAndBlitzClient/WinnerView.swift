import SwiftUI
import SpritzAndBlitzDTOs

struct WinnerView: View {
    let winner: MatchDTO.UserMatchStatus
    let scores: [MatchDTO.UserMatchStatus]
    
    init(winner: MatchDTO.UserMatchStatus, scores: [MatchDTO.UserMatchStatus]) {
        self.winner = winner
        self.scores = scores
    }
    
    var body: some View {
        VStack {
            Text("Winner: \(winner.name)")
            Text("Final Scores")
            ForEach(scores) { score in
                Text("\(score.name): \(score.score)")
            }
        }
        .padding(20)
    }
}

#Preview {
    WinnerView(winner: .init(name: "foo", score: 75), scores: [
        .init(name: "foo", score: 75),
        .init(name: "bar", score: 10),
        .init(name: "caitlin", score: -100),
        .init(name: "jeepers", score: 60)
    ])
}

extension MatchDTO.UserMatchStatus: @retroactive Identifiable {
    public var id: String { name }
}
