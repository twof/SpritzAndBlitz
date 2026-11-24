import SwiftUI
import SpritzAndBlitzDTOs

struct LobbyView: View {
    let authedClient: AuthedClient
    @Binding var navPath: NavigationPath
    @State var state: LobbyDTO
    @State var task: Task<Void, Never>? = nil
    @Environment(\.dismiss) var dismiss
    
    init(
        authedClient: AuthedClient,
        state: LobbyDTO,
        navPath: Binding<NavigationPath>,
        task: Task<Void, Never>? = nil
    ) {
        self.authedClient = authedClient
        self.state = state
        self.task = task
        self._navPath = navPath
    }
    
    var body: some View {
        VStack {
            Text("Lobby ID: \(state.code.uuidString)")
                .copyable([state.code.uuidString])
                .textSelection(.enabled)
            
            ForEach(state.users) { player in
                Text(player.name)
            }
            
            HStack {
                Button("Start Game") {
                    self.task?.cancel()
                    self.task = Task {
                        do {
                            let match = try await startGame()
                            navPath.append(Destination.matchView(
                                authedClient: authedClient,
                                matchId: match.id
                            ))
                        } catch {
                            print(error)
                        }
                    }
                }
                
                Button("Leave Lobby") {
                    self.task?.cancel()
                    self.task = Task {
                        do {
                            _ = try await leaveLobby()
                            dismiss()
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        }
        .padding(20)
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(200))
                    self.state = try await getLobbyStatus()
                    if let createdMatch = state.match {
                        navPath.append(Destination.matchView(
                            authedClient: authedClient,
                            matchId: createdMatch.id
                        ))
                    }
                } catch is CancellationError { }
                catch {
                    print(error)
                }
            }
        }
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .matchView(authedClient, matchId):
                MatchView(authedClient: authedClient, matchId: matchId, navPath: $navPath)   
            }
        }
    }
    
    func getLobbyStatus() async throws -> LobbyDTO {
        let data = try await authedClient.authedGet(API.url("lobby/\(state.code)/status"))
        return try JSONDecoder().decode(LobbyDTO.self, from: data)
    }
    
    func leaveLobby() async throws -> LobbyDTO {
        let data = try await authedClient.authedPost(API.url("lobby/\(state.code)/leave"))
        return try JSONDecoder().decode(LobbyDTO.self, from: data)
    }
    
    func startGame() async throws -> MatchDTO {
        let data = try await authedClient.authedPost(API.url("lobby/\(state.code)/ready"))
        return try JSONDecoder().decode(MatchDTO.self, from: data)
    }
}

extension LobbyView {
    enum Destination: Hashable {
        case matchView(authedClient: AuthedClient, matchId: UUID)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    LobbyView(
        authedClient: AuthedClient(sessionToken: "foo", playerName: "foo"),
        state: .init(code: UUID(), users: [
            .init(name: "foo"),
            .init(name: "bar"),
            .init(name: "caitlin"),
            .init(name: "jeepers")
        ], match: nil),
        navPath: $navPath
    )
}
