public import SpritzAndBlitzDTOs
public import Vapor

// DTOs live in the shared SpritzAndBlitzDTOs package so the client can use them.
// Vapor conformances stay here to keep that package dependency-free.
extension LobbyDTO: @retroactive Content {}
extension LoginDTO: @retroactive Content {}
extension MatchDTO: @retroactive Content {}
extension RoundScoreDTO: @retroactive Content {}
extension SignupDTO: @retroactive Content {}
extension UserDTO: @retroactive Content {}

extension UserDTO {
    func toModel() -> User {
        let model = User()
        model.id = self.id
        model.name = self.name
        return model
    }
}
