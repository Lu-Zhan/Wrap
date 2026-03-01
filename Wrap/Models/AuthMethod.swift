import Foundation

enum AuthMethod: String, Codable, CaseIterable {
    case password
    case privateKey

    var displayName: String {
        switch self {
        case .password: "Password"
        case .privateKey: "Private Key"
        }
    }
}
