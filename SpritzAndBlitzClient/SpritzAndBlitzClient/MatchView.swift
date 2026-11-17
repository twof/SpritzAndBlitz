import SwiftUI
import SpritzAndBlitzDTOs

struct MatchView: View {
    let authedClient: AuthedClient
    let matchId: UUID
    @Binding var navPath: NavigationPath
    @State var round: String
    @State var state: State
    @State var task: Task<Void, Never>? = nil
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    init(
        authedClient: AuthedClient,
        matchId: UUID,
        navPath: Binding<NavigationPath>,
        round: String = "",
        state: State = State.scoring(score: 0, didBlitz: false),
        task: Task<Void, Never>? = nil
    ) {
        self.authedClient = authedClient
        self.matchId = matchId
        self._navPath = navPath
        self.round = round
        self.state = state
        self.task = task
    }
    
    var body: some View {
        VStack {
            Text("Round \(round)")
            
            switch state {
            case let .scoring(score, didBlitz):
                scoringView(score: score, didBlitz: didBlitz)
            case let .waiting(match):
                waiting(match: match)
            }
            
        }
        .padding(20)
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .win(finalScore, winner):
                WinnerView(winner: winner, scores: finalScore)
            }
        }
    }
    
    func scoringView(score: Int, didBlitz: Bool) -> some View {
        VStack {
            Toggle(
                "Did Blitz",
                isOn: Binding(
                    get: {
                        didBlitz
                    },
                    set: {
                        self.state = .scoring(score: score, didBlitz: $0)
                    }
                )
            )
            
            TextField(
                "Score",
                value: Binding(
                    get: {
                        score
                    },
                    set: {
                        self.state = .scoring(score: $0, didBlitz: didBlitz)
                    }
                ),
                formatter: formatter
            )
            .textFieldStyle(.roundedBorder)
            .padding()
            
            Button("Submit") {
                let scoreModel = RoundScoreDTO(score: score, didBlitz: didBlitz)
                let url = URL(string: "http://localhost:8080/match/\(matchId.uuidString)/score")!
                
                self.task = Task {
                    do {
                        let data = try await authedClient.authedPost(url, content: scoreModel)
                        let matchDto = try JSONDecoder().decode(MatchDTO.self, from: data)
                        self.state = .waiting(match: matchDto)
                    } catch {
                        print("error")
                    }
                }
            }
        }
    }
    
    private enum ScoreStatus {
        case waiting
        case score(Int)
    }
    
    private struct PlayerScore: Identifiable {
        var id: String { name }
        let name: String
        let score: ScoreStatus
    }
    
    fileprivate func waiting(match: MatchDTO) -> some View {
        let players = match.totals.map(\.name)
        var currentRound = players.reduce(into: [String: ScoreStatus]()) { partialResult, player in
            partialResult[player] = .waiting
        }
        
        for submittedScore in match.currentRound {
            currentRound[submittedScore.name] = .score(submittedScore.score)
        }
        
        let playerScores = currentRound.map { PlayerScore(name: $0, score: $1) }
        
        return VStack {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(playerScores) { player in
                    switch player.score {
                    case let .score(score):
                        Text("✅ \(player.name): \(String(score))")
                    case .waiting:
                        Text("🕒 \(player.name)")
                    }
                }
            }
            .padding()
        }
        .task {
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(200))
                    let data = try await authedClient
                        .authedGet(URL(string: "http://localhost:8080/match/\(matchId)/status")!)
                    let match = try JSONDecoder().decode(MatchDTO.self, from: data)
                    if let winner = match.winner {
                        self.navPath
                            .append(Destination.win(finalScore: match.totals, winner: winner))
                    } else if !match.currentRound.contains(where: { $0.name == authedClient.playerName }) {
                        self.state = .scoring(score: 0, didBlitz: false)
                    } else {
                        self.state = .waiting(match: match)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
}

extension MatchView {
    enum Destination: Hashable {
        case win(finalScore: [MatchDTO.UserMatchStatus], winner: MatchDTO.UserMatchStatus)
    }
    
    enum State {
        case scoring(score: Int, didBlitz: Bool)
        case waiting(match: MatchDTO)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    MatchView(
        authedClient: AuthedClient(sessionToken: "foo", playerName: "foo"),
        matchId: UUID(),
        navPath: $navPath,
        round: "1",
        state: .scoring(score: 0, didBlitz: false)
    )
}
