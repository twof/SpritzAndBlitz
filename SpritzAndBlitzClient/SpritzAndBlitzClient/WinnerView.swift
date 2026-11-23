import SwiftUI
import SpritzAndBlitzDTOs

struct WinnerView: View {
    let winner: MatchDTO.UserMatchStatus
    let scores: [MatchDTO.UserMatchStatus]
    @Binding var navPath: NavigationPath
    
    init(
        winner: MatchDTO.UserMatchStatus,
        scores: [MatchDTO.UserMatchStatus],
        navPath: Binding<NavigationPath>
    ) {
        self.winner = winner
        self.scores = scores
        self._navPath = navPath
    }
    
    var body: some View {
        VStack {
            Text("Winner: \(winner.name)")
            Text("Final Scores")
            ForEach(scores) { score in
                Text("\(score.name): \(score.score)")
            }
            Button {
                navPath = NavigationPath()
            } label: {
                Text("Return To Main Menu")
            }
        }
        .padding(20)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    WinnerView(
        winner: .init(name: "foo", score: 75),
        scores: [
            .init(name: "foo", score: 75),
            .init(name: "bar", score: 10),
            .init(name: "caitlin", score: -100),
            .init(name: "jeepers", score: 60)
        ],
        navPath: $navPath
    )
}

extension MatchDTO.UserMatchStatus: @retroactive Identifiable {
    public var id: String { name }
}
