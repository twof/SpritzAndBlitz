import Configuration
import SystemPackage
import ConsoleLogger
import Logging
import Vapor
import Foundation

@main
enum Entrypoint {
    static func main() async throws {
        try await withLogger(.init(label: "vapor5.logger")) { _ in
            let envPath = String(#filePath.split(separator: "/Sources/")[0]) + "/.env"
            let filePath = FilePath(envPath)
            let config = try await ConfigReader(providers: [
                CommandLineArgumentsProvider(),
                EnvironmentVariablesProvider(
                    environmentFilePath: filePath
                ),
            ])
            ConsoleLogger.bootstrapWithConfigReader(config: config)

            let app = try Application(configReader: config)
            
            do {
                try await configure(app)
                try await app.run()
                try await app.shutdown()
            } catch {
                try? await app.shutdown()
                throw error
            }
        }
    }
}
