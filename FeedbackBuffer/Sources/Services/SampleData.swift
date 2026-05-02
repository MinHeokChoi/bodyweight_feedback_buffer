import Foundation

enum SampleData {
    static func defaultSkills() -> [Skill] {
        DefaultSkill.allCases.map { Skill(name: $0.rawValue, symbolName: $0.symbolName) }
    }
}
