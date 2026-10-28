import FluentKit
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct UserDTO: Content {
    var id: UUID?
    var name: String
    
    func toModel() -> User {
        let model = User()
        
        model.id = self.id
        model.name = self.name
        return model
    }
}
