import SwiftUI
import SpritzAndBlitzDTOs
import Dependencies

struct LoginView: View {
    @State var name = ""
    @State var password = ""
    @Binding var navPath: NavigationPath
    @State var task: Task<Void, Never>? = nil
    @ObservationIgnored
    @Dependency(\.keychainClient) var keychainClient
    
    var body: some View {
        VStack {
            TextField("Name", text: $name)
            SecureField("Password", text: $password)
            Button("Submit") {
                guard !name.isEmpty else { return }
                do {
                    let userDto = SignupDTO(name: name, password: password)
                    let encodedUser = try JSONEncoder().encode(userDto)
                    let url = API.url("login")
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpMethod = "POST"
                    
                    self.task = Task {
                        do {
                            let (data, _) = try await URLSession.shared.upload(
                                for: request,
                                from: encodedUser
                            )
                            let loginDto = try JSONDecoder().decode(LoginDTO.self, from: data)
                            keychainClient.set(value: loginDto.sessionToken, forKey: "token")
                            keychainClient.set(value: name, forKey: "name")
                            self.navPath.append(
                                Destination.mainMenu(
                                    authedClient: AuthedClient(
                                        sessionToken: loginDto.sessionToken,
                                        playerName: name
                                    )
                                )
                            )
                        } catch {
                            print("error")
                        }
                    }
                } catch {
                    print("error", error)
                }
                
            }
        }
        .padding(20)
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .mainMenu(authedClient):
                MainMenuView(authedClient: authedClient, navPath: $navPath)
            }
        }
    }
}

extension LoginView {
    enum Destination: Hashable {
        case mainMenu(authedClient: AuthedClient)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    LoginView(navPath: $navPath)
}
