@testable import SpritzAndBlitzServer
import HTTPTypes
import Testing
import Vapor
import VaporTesting
import FluentKit

@Suite("App Tests", .withApp())
struct SpritzAndBlitzServerTests {
    @Test("Test Hello World Route")
    func helloWorld() async throws {
        try await app.testing { client in
            let res = try await client.get("hello")
            #expect(res.status == .ok)
            try #expect(await res.body.requireString() == "Hello, world!")
        }
    }
}
extension UserDTO: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
