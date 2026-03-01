import Foundation
import SwiftData

@Model
final class ServerConnection {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var group: String?
    var createdAt: Date
    var lastConnectedAt: Date?

    init(
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .password,
        group: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.group = group
        self.createdAt = Date()
    }
}
