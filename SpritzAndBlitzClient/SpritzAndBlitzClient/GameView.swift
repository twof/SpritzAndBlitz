import SwiftUI

fileprivate enum Destination: Hashable {
    case gameView(authedClient: AuthedClient)
}

fileprivate struct PlayerReadyUpStatus: Identifiable {
    var id: String { name }
    let name: String
    let isReady: Bool
}

fileprivate struct PlayerScore: Identifiable {
    var id: String { name }
    let name: String
    let ready: Bool
    let score: Int
}

fileprivate enum State {
    case scoring(score: Int)
    case waiting(ready: Bool, playerScores: [PlayerScore])
    case nextTable(ready: Bool, playerStatus: [PlayerReadyUpStatus])
}

struct GameView: View {
    let authedClient: AuthedClient
    @State var round: String
    @State var table: String
    @State fileprivate var state: State
    @State var task: Task<Void, Never>? = nil
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    init(authedClient: AuthedClient) {
        self.round = "1"
        self.table = "1"
        self.state = State.nextTable(ready: false, playerStatus: [])
    }
    
    fileprivate init(
        authedClient: AuthedClient,
        round: String = "",
        table: String = "",
        state: State = State.nextTable(ready: false, playerStatus: []),
        task: Task<Void, Never>? = nil
    ) {
        self.authedClient = authedClient
        self.round = round
        self.table = table
        self.state = state
        self.task = task
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Table \(table)")
                Text("-")
                Text("Round \(round)")
            }
            
            switch state {
            case .scoring(let score):
                scoringView(score: score)
            case let .waiting(ready, playerScores):
                waiting(ready: ready, playerScores: playerScores)
            case let .nextTable(ready, playerStatus):
                nextTable(ready: ready, playerStatus: playerStatus)
            }
            
        }
        .padding(20)
    }
    
    func scoringView(score: Int) -> some View {
        VStack {
            TextField(
                "Score",
                value: Binding(get: { score }, set: { self.state = .scoring(score: $0) }),
                formatter: formatter
            )
            .textFieldStyle(.roundedBorder)
            .padding()
            
            Button("Submit") {
                do {
                    let scoreModel = Score(
                        id: nil,
                        round: round,
                        table: table,
                        score: score
                    )
                    let encodedScore = try JSONEncoder().encode(scoreModel)
                    let url = URL(string: "localhost:8080/scores")!
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpMethod = "POST"
                    
                    self.task = Task {
                        do {
                            let (data, _) = try await URLSession.shared.upload(
                                for: request,
                                from: encodedScore
                            )
                            let score = try JSONDecoder().decode(Score.self, from: data)
                            self.state = .waiting(ready: false, playerScores: [])
                        } catch {
                            print("error")
                        }
                    }
                } catch {
                    print("error", error)
                }
            }
        }
    }
    
    fileprivate func waiting(ready: Bool, playerScores: [PlayerScore]) -> some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(playerScores) { playerScore in
                    Text(
                        "\(playerScore.ready ? "✅" : "🕒 ")\(playerScore.name): \(String(playerScore.score))"
                    )
                }
            }
            .padding()
            
            Button {
                print("Ready Up")
                self.state = .waiting(ready: true, playerScores: playerScores)
            } label: {
                Text("Ready Up")
            }
            .padding()
            .disabled(ready)
        }
        .task {
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(200))
                    // Request round scores for table
                    // GET /user/:id/current_round_scores
                }
            } catch {
                print(error)
            }
        }
    }
    
    fileprivate func nextTable(ready: Bool, playerStatus: [PlayerReadyUpStatus]) -> some View {
        VStack {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(playerStatus) { player in
                    Text("\(player.isReady ? "✅" : "🕒") \(player.name)")
                }
            }
            .padding()
            
            Text("Move to your assigned table, and hit Ready Up when you're seated")
                .padding()
            
            Button {
                print("ready up")
                // post /user/:id/table/:number/ready
                
                if playerStatus.reduce(true, { $0 && $1.isReady }) {
                    print("all ready")
                    let playerScores = playerStatus.map {
                        PlayerScore(name: $0.name, ready: false, score: 0)
                    }
                    self.state = .waiting(ready: false, playerScores: playerScores)
                } else {
                    self.state = .nextTable(ready: true, playerStatus: playerStatus)
                }
                
            } label: {
                Text("Ready Up")
            }
            .padding()
            .disabled(ready)
        }
        .task {
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(200))
                    
                }
            } catch {
                print(error)
            }
        }
    }
}

#Preview {
    GameView(
        userId: UUID(),
        round: "1",
        table: "2",
        state: .nextTable(
            ready: false,
            playerStatus: [
                .init(name: "Alex", isReady: true),
                .init(name: "Brian", isReady: true),
                .init(name: "Caitlin", isReady: true)
            ]
        )
    )
}
