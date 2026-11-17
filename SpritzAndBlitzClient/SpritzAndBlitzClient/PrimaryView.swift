import SwiftUI
import KeychainSwift



struct PrimaryView: View {
    @State var navPath = NavigationPath()
    let keychainManger = KeychainSwift()
    
    var body: some View {
        NavigationStack(path: $navPath) {
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
                case let .mainMenu(authedClient):
                    MainMenuView(
                        authedClient: authedClient,
                        navPath: $navPath
                    )
                }
            }
        }.task {
            if let token = keychainManger.get("token"), let name = keychainManger.get("name") {
                navPath.append(Destination.mainMenu(AuthedClient(
                    sessionToken: token,
                    playerName: name
                )))
            }
        }
    }
}

extension PrimaryView {
    enum Destination: Hashable {
        case registration
        case login
        case mainMenu(AuthedClient)
    }
}

#Preview {
    PrimaryView()
}

