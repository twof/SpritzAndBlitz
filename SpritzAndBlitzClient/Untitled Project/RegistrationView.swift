import SwiftUI

fileprivate enum Destination: Hashable {
    case gameView(userId: String, userName: String)
}

struct RegistrationView: View {
    @State var name = ""
    @State fileprivate var navigationPath: [Destination] = []
    @State var task: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                TextField("Name", text: $name)
                Button("Submit") {
                    guard !name.isEmpty else { return }
                    do {
                        let user = User(id: nil, name: name)
                        let encodedUser = try JSONEncoder().encode(user)
                        let url = URL(string: "localhost:8080/users")!
                        var request = URLRequest(url: url)
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.httpMethod = "POST"
                        
                        self.task = Task {
                            do {
                                let (data, _) = try await URLSession.shared.upload(
                                    for: request,
                                    from: encodedUser
                                )
                                let user = try JSONDecoder().decode(User.self, from: data)
                                self.navigationPath
                                    .append(
                                        .gameView(userId: user.id!.uuidString, userName: user.name)
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
            case let .gameView(userId, userName):
                
            }
        }
        
    }
}

#Preview {
    RegistrationView()
}
