import SwiftUI

struct UserSelectionView: View {
    @State var name = ""
    
    var body: some View {
        VStack {
            TextField("Name", text: $name)
            Button("Submit") {
                print("send")
            }
        }.padding(20)
    }
}

#Preview {
    UserSelectionView()
}
