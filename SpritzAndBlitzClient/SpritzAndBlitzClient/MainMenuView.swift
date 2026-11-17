import SwiftUI
import SpritzAndBlitzDTOs

struct MainMenuView: View {
    let authedClient: AuthedClient
    @Binding var navPath: NavigationPath
    @State var lobbyId: String = ""
    
    var body: some View {
        VStack {
            Button("Create Lobby") {
                Task {
                    do {
                        let lobby = try await createLobby()
                        navPath.append(Destination.lobby(lobby))
                    } catch {
                        print(error)
                    }
                }
            }
            HStack {
                Button("Join Lobby") {
                    Task {
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
            
        }
        .padding(20)
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .lobby(lobby):
                LobbyView(authedClient: authedClient, state: lobby, navPath: $navPath)
            }
        }
    }
    
    func createLobby() async throws -> LobbyDTO {
        let data = try await authedClient.authedPost(URL(string: "http://localhost:8080/lobby")!)
        return try JSONDecoder().decode(LobbyDTO.self, from: data)
    }
    
    func joinLobby(id: UUID) async throws -> LobbyDTO {
        let data = try await authedClient.authedPost(
            URL(string: "http://localhost:8080/lobby/\(id.uuidString)/join")!
        )
        return try JSONDecoder().decode(LobbyDTO.self, from: data)
    }
}

extension MainMenuView {
    enum Destination: Hashable {
        case lobby(LobbyDTO)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    MainMenuView(
        authedClient: AuthedClient(sessionToken: "foo", playerName: "bar"),
        navPath: $navPath
    )
}

