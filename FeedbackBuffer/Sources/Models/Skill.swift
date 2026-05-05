import Foundation

struct Skill: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var symbolName: String

    init(id: UUID = UUID(), name: String, symbolName: String = "dumbbell.fill") {
        self.id = id
        self.name = name
        self.symbolName = symbolName
    }
}

enum DefaultSkill: String, CaseIterable {
    case handstand = "Handstand"
    case bridgeCircle = "Bridge Circle"
    case cartwheel = "Cart Wheel"
    case qdr = "Q.D.R"
    case hspu = "HSPU"
    case pullUps = "Pull ups"
    case frontLever = "Front Lever"
    case dips = "Dips"
    case muscleUp = "Muscle Up"
    case piaStretching = "Pia stretching"

    var symbolName: String {
        switch self {
        case .handstand: "handstand.full"
        case .bridgeCircle: "bridge.full"
        case .cartwheel: "cartwheel.full"
        case .qdr: "qdr.full"
        case .hspu: "hspu.full"
        case .pullUps: "pull.ups.full"
        case .frontLever: "front.lever.full"
        case .dips: "dips.full"
        case .muscleUp: "muscle.up.full"
        case .piaStretching: "pia.stretching.full"
        }
    }
}
