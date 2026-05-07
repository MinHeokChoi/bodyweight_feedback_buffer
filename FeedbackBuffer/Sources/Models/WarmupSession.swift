import Foundation

struct WarmupSession: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var items: [WarmupItem]

    init(id: UUID = UUID(), name: String, items: [WarmupItem]) {
        self.id = id
        self.name = name
        self.items = items
    }
}

enum DefaultWarmupSession {
    static let initialName = "기본 웜업"
}
