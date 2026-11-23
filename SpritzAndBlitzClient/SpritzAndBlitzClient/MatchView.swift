import SwiftUI
import SpritzAndBlitzDTOs
import Dependencies

struct MatchView: View {
    let authedClient: AuthedClient
    let matchId: UUID
    @Binding var navPath: NavigationPath
    @State var state: State
    @State var task: Task<Void, Never>? = nil
    @State var status: MatchDTO?
    @ObservationIgnored
    @Dependency(\.postScoreClient) var postScoreClient
    @ObservationIgnored
    @Dependency(\.getMatchStatusClient) var getMatchStatusClient
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    init(
        authedClient: AuthedClient,
        matchId: UUID,
        navPath: Binding<NavigationPath>,
        state: State = State.scoring(score: 0, didBlitz: false),
        status: MatchDTO? = nil,
        task: Task<Void, Never>? = nil
    ) {
        self.authedClient = authedClient
        self.matchId = matchId
        self._navPath = navPath
        self.state = state
        self.status = status
        self.task = task
    }
    
    var body: some View {
        VStack {
            scoreboard()
            VStack {
                Text("Round \(status?.roundNumber ?? 1)")
                    .font(.title)
                switch state {
                case let .scoring(score, didBlitz):
                    scoringView(score: score, didBlitz: didBlitz)
                case let .waiting(match):
                    waiting(match: match)
                }
                Spacer()
            }
            .padding(.top, 50)
            
            Spacer()
        }
        .padding(20)
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .win(finalScore, winner):
                WinnerView(winner: winner, scores: finalScore, navPath: $navPath)
            }
        }
    }
    
    func scoreboard() -> some View {
        HStack {
            VStack {
                Text("Score Board")
                    .font(.largeTitle)
                    .padding(.bottom, 15)
                ForEach(status?.totals ?? []) { score in
                    Text("\(score.name): \(score.score)")
                }
            }
//            Spacer()
        }
        .task {
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(200))
                    
                    self.status = try await getMatchStatusClient(authedClient, matchId)
                }
            } catch is CancellationError {}
            catch {
                print(error)
            }
        }
        .onChange(of: status) { oldValue, newValue in
            guard let status else { return }
            if let winner = status.winner {
                print("winner")
                self.navPath
                    .append(Destination.win(finalScore: status.totals, winner: winner))
            } else if !status.currentRound.contains(where: { $0.name == authedClient.playerName }) {
                self.state = .scoring(score: 0, didBlitz: false)
            } else {
                self.state = .waiting(match: status)
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
                self.task?.cancel()
                self.task = Task {
                    do {
                        let scoreModel = RoundScoreDTO(score: score, didBlitz: didBlitz)
                        let matchDto = try await postScoreClient(authedClient, matchId, scoreModel)
                        self.state = .waiting(match: matchDto)
                    } catch is CancellationError {}
                    catch {
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
        
        let playerScores = currentRound
            .map { PlayerScore(name: $0, score: $1) }
            .sorted { left, right in
                switch (left.score, right.score) {
                case (.waiting, .waiting): left.name > right.name
                case (_, .waiting): true
                case (.waiting, _): false
                case (.score, .score): left.name > right.name
                }
            }
        
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
    withDependencies { dependencyValues in
        dependencyValues.getMatchStatusClient = { _, _ in
            .init(
                id: UUID(),
                roundNumber: 3,
                currentRound: [],
                totals: [
                    .init(name: "foo", score: 10),
                    .init(name: "bar", score: 20),
                    .init(name: "Caitlin", score: 65),
                    .init(name: "jeepers", score: 65)
                ],
                lastRound: nil,
                winner: nil
            )
        }
    } operation: {
        MatchView(
            authedClient: AuthedClient(sessionToken: "foo", playerName: "foo"),
            matchId: UUID(),
            navPath: $navPath,
            state: .scoring(score: 0, didBlitz: false),
            status: .init(
                id: UUID(),
                roundNumber: 3,
                currentRound: [],
                totals: [
                    .init(name: "foo", score: 10),
                    .init(name: "bar", score: 20),
                    .init(name: "Caitlin", score: 55),
                    .init(name: "jeepers", score: 65)
                ],
                lastRound: nil,
                winner: nil
            )
        )
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    withDependencies { dependencyValues in
        dependencyValues.getMatchStatusClient = { _, _ in
                .init(
                    id: UUID(),
                    roundNumber: 3,
                    currentRound: [
                        .init(name: "foo", score: 1),
                        .init(name: "bar", score: 3),
                        .init(name: "Caitlin", score: 16),
                    ],
                    totals: [
                        .init(name: "foo", score: 10),
                        .init(name: "bar", score: 20),
                        .init(name: "Caitlin", score: 65),
                        .init(name: "jeepers", score: 65)
                    ],
                    lastRound: nil,
                    winner: nil
                )
        }
    } operation: {
        MatchView(
            authedClient: AuthedClient(sessionToken: "foo", playerName: "foo"),
            matchId: UUID(),
            navPath: $navPath,
            state: .waiting(match: .init(
                id: UUID(),
                roundNumber: 3,
                currentRound: [],
                totals: [
                    .init(name: "foo", score: 10),
                    .init(name: "bar", score: 20),
                    .init(name: "Caitlin", score: 55),
//                    .init(name: "jeepers", score: 65)
                ],
                lastRound: nil,
                winner: nil
            )),
            status: .init(
                id: UUID(),
                roundNumber: 3,
                currentRound: [],
                totals: [
                    .init(name: "foo", score: 10),
                    .init(name: "bar", score: 20),
                    .init(name: "Caitlin", score: 55),
                    .init(name: "jeepers", score: 65)
                ],
                lastRound: nil,
                winner: nil
            )
        )
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    withDependencies { dependencyValues in
        dependencyValues.getMatchStatusClient = { _, _ in
                .init(
                    id: UUID(),
                    roundNumber: 3,
                    currentRound: [
                        .init(name: "foo", score: 1),
                        .init(name: "bar", score: 3),
                        .init(name: "Caitlin", score: 16),
                        .init(name: "jeepers", score: 10)
                    ],
                    totals: [
                        .init(name: "foo", score: 75),
                        .init(name: "bar", score: 20),
                        .init(name: "Caitlin", score: 65),
                        .init(name: "jeepers", score: 65)
                    ],
                    lastRound: nil,
                    winner: .init(name: "foo", score: 75)
                )
        }
    } operation: {
        NavigationStack(path: $navPath) {
            MatchView(
                authedClient: AuthedClient(sessionToken: "foo", playerName: "foo"),
                matchId: UUID(),
                navPath: $navPath,
                state: .waiting(match: .init(
                    id: UUID(),
                    roundNumber: 3,
                    currentRound: [],
                    totals: [
                        .init(name: "foo", score: 10),
                        .init(name: "bar", score: 20),
                        .init(name: "Caitlin", score: 55),
                        .init(name: "jeepers", score: 65)
                    ],
                    lastRound: nil,
                    winner: nil
                )),
                status: .init(
                    id: UUID(),
                    roundNumber: 3,
                    currentRound: [],
                    totals: [
                        .init(name: "foo", score: 10),
                        .init(name: "bar", score: 20),
                        .init(name: "Caitlin", score: 55),
                        .init(name: "jeepers", score: 65)
                    ],
                    lastRound: nil,
                    winner: .init(name: "foo", score: 75)
                )
            )
        }
    }
}
