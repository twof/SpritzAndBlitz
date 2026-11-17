import SwiftUI
import SpritzAndBlitzDTOs
import KeychainSwift

struct RegistrationView: View {
    @State var name = ""
    @State var password = ""
    @Binding var navPath: NavigationPath
    @State var task: Task<Void, Never>? = nil
    private let keychain = KeychainSwift()
    
    var body: some View {
        VStack {
            TextField("Name", text: $name)
            SecureField("Password", text: $password)
            Button("Submit") {
                guard !name.isEmpty else { return }
                do {
                    let userDto = SignupDTO(name: name, password: password)
                    let encodedUser = try JSONEncoder().encode(userDto)
                    let url = URL(string: "http://localhost:8080/signup")!
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
                            keychain.set(loginDto.sessionToken, forKey: "token")
                            keychain.set(name, forKey: "name")
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

extension RegistrationView {
    enum Destination: Hashable {
        case mainMenu(authedClient: AuthedClient)
    }
}

#Preview {
    @Previewable @State var navPath = NavigationPath()
    RegistrationView(navPath: $navPath)
}
