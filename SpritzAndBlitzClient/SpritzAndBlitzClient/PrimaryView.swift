import SwiftUI
import Dependencies

struct PrimaryView: View {
    @State var navPath = NavigationPath()
    @State var state: State
    @ObservationIgnored
    @Dependency(\.keychainClient) var keychainClient
    @ObservationIgnored
    @Dependency(\.getTokenIsValidClient) var tokenIsValidClient
    
    var body: some View {
        NavigationStack(path: $navPath) {
            switch state {
            case .loading:
                ProgressView().progressViewStyle(.circular)
            case let .loggedIn(token, name):
                MainMenuView(
                    authedClient: AuthedClient(
                        sessionToken: token,
                        playerName: name
                    ),
                    navPath: $navPath
                )
            case .loggedOut:
                VStack {
                    Text("Welcome to Spritz and Blitz!")
                    Button("New Player") {
                        navPath.append(Destination.registration)
                    }
                    Button("Returning Player") {
                        navPath.append(Destination.login)
                    }
                }
                .padding(20)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .registration:
                        RegistrationView(navPath: $navPath)
                    case .login:
                        LoginView(navPath: $navPath)
                    }
                }
            }
        }
        .task {
            do {
                if let token = keychainClient.get("token"), let name = keychainClient.get("name") {
                    let tokenIsValid = try await tokenIsValidClient(AuthedClient(sessionToken: token, playerName: name))
                    if tokenIsValid {
                        state = .loggedIn(token: token, name: name)
                    } else {
                        state = .loggedOut
                    }
                } else {
                    state = .loggedOut
                }
            } catch {
                state = .loggedOut
                print(error)
            }
        }
    }
}

extension PrimaryView {
    enum State {
        case loading
        case loggedIn(token: String, name: String)
        case loggedOut
    }
}

extension PrimaryView {
    enum Destination: Hashable {
        case registration
        case login
    }
}

#Preview {
    withDependencies { dependencies in
        dependencies.keychainClient.get = { key in
            if key == "name" {
                return "foo"
            }
            if key == "token" {
                return "bar"
            }
            
            return nil
        }
        
        dependencies.getTokenIsValidClient = { authedClient in
            return false
        }
    } operation: {
        PrimaryView(state: .loading)
    }
}

