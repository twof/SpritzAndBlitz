import SwiftUI

enum Destinations: Hashable {
    case registration
    case userSelection
}

struct PrimaryView: View {
    @State var navPath: [Destinations] = []
    
    var body: some View {
        NavigationStack(path: $navPath) {
            VStack {
                Text("Welcome to Spritz and Blitz!")
                Button("New Player") {
                    navPath.append(.registration)
                }
                Button("Returning Player") {
                    navPath.append(.userSelection)
                }
            }
            .padding(20)
            .navigationDestination(for: Destinations.self) { destination in
                switch destination {
                case .registration:
                    RegistrationView()
                case .userSelection:
                    UserSelectionView()
                }
            }
        }
    }
}

#Preview {
    PrimaryView()
}

