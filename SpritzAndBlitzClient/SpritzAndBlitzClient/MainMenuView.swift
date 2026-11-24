import SwiftUI
import SpritzAndBlitzDTOs

struct MainMenuView: View {
    let authedClient: AuthedClient
    @Binding var navPath: NavigationPath
    @State var lobbyId: String = ""
    @State var task: Task<Void, Never>?
    @State var ongoingMatch: MatchDTO?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Join Lobby") {
                    self.task?.cancel()
                    self.task = Task {
                        do {
                            if let id = UUID(uuidString: lobbyId) {
                                let lobby = try await joinLobby(id: id)
                                navPath.append(Destination.lobby(lobby))
                            }
                        } catch {
                            print(error)
                        }
                    }
                }
                TextField("Lobby ID", text: $lobbyId)
            }
            Button("Create Lobby") {
                self.task?.cancel()
                self.task = Task {
                    do {
                        let lobby = try await createLobby()
                        navPath.append(Destination.lobby(lobby))
                    } catch {
                        print(error)
                    }
                }
            }
            
            if let ongoingMatch {
                Button("Rejoin Match") {
                    navPath.append(Destination.ongoingMatch(ongoingMatch))
                }
            }
            
        }
        .padding(20)
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .lobby(lobby):
                LobbyView(authedClient: authedClient, state: lobby, navPath: $navPath)
            case let .ongoingMatch(match):
                MatchView(authedClient: authedClient, matchId: match.id, navPath: $navPath)
            }
        }
        .task {
            Task {
                do {
                    self.ongoingMatch = try await checkOngoingMatch()
                } catch  {
                    print(error)
                }
            }
        }
    }
    
    func createLobby() async throws -> LobbyDTO {
        let data = try await authedClient.authedPost(API.url("lobby"))
        return try JSONDecoder().decode(LobbyDTO.self, from: data)
    }
    
    func joinLobby(id: UUID) async throws -> LobbyDTO {
        let data = try await authedClient.authedPost(
            API.url("lobby/\(id.uuidString)/join")
        )
        return try JSONDecoder().decode(LobbyDTO.self, from: data)
    }
    
    func checkOngoingMatch() async throws -> MatchDTO? {
        let data = try await authedClient.authedPost(API.url("match/current"))
        return try? JSONDecoder().decode(MatchDTO.self, from: data)
    }
}

extension MainMenuView {
    enum Destination: Hashable {
        case lobby(LobbyDTO)
        case ongoingMatch(MatchDTO)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    MainMenuView(
        authedClient: AuthedClient(sessionToken: "foo", playerName: "bar"),
        navPath: $navPath,
        ongoingMatch: .mock
    )
}

extension MatchDTO {
    static var mock: MatchDTO {
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
}

