import SwiftUI
import SpritzAndBlitzDTOs

fileprivate enum Destination: Hashable {
    case gameView(authedClient: AuthedClient)
}

struct RegistrationView: View {
    @State var name = ""
    @State var password = ""
    @State fileprivate var navigationPath: [Destination] = []
    @State var task: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                TextField("Name", text: $name)
                // TODO: Style as password
                TextField("Password", text: $password)
                Button("Submit") {
                    guard !name.isEmpty else { return }
                    do {
                        let userDto = SignupDTO(name: name, password: password)
                        let encodedUser = try JSONEncoder().encode(userDto)
                        let url = URL(string: "localhost:8080/signup")!
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
                                self.navigationPath.append(
                                    .gameView(
                                        authedClient: AuthedClient(
                                            sessionToken: loginDto.sessionToken
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
        }.navigationDestination(for: Destination.self) { destination in
            switch destination {
            case let .gameView(authedClient):
                GameView(authedClient: authedClient)
            }
        }
        
    }
}

#Preview {
    RegistrationView()
}
