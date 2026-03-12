import Foundation

struct WOLHost: Identifiable, Codable {
    let id: String // uuid
    let interface: String
    let interfaceName: String?
    let mac: String
    let description: String

    var displayName: String {
        description.isEmpty ? mac : description
    }

    enum CodingKeys: String, CodingKey {
        case id = "uuid"
        case interface
        case interfaceName = "%interface"
        case mac
        case description = "descr"
    }
}
