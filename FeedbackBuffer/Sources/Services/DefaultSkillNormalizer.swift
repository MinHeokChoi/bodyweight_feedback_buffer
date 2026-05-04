import Foundation

enum DefaultSkillNormalizer {
    private static let canonicalDefaultSkillNames = DefaultSkill.allCases.map(\.rawValue)

    private static let deprecatedDefaultSkillNames: Set<String> = [
        "백레버",
        "백 레버",
        "Back Lever"
    ]

    private static let defaultSkillAliases: [String: DefaultSkill] = [
        "물구나무": .handstand,
        "Handstand": .handstand,
        "브릿지": .bridgeCircle,
        "Bridge Circle": .bridgeCircle,
        "카트휠": .cartwheel,
        "Cart Wheel": .cartwheel,
        "Q.D.R": .qdr,
        "HSPU": .hspu,
        "Pull Ups": .pullUps,
        "Pull ups": .pullUps,
        "프론트레버": .frontLever,
        "Front Lever": .frontLever,
        "딥스": .dips,
        "Dips": .dips,
        "머슬업": .muscleUp,
        "Muscle Up": .muscleUp,
        "Pia Stretching": .piaStretching,
        "Pia stretching": .piaStretching,
        "기타": .other
    ]

    static func normalize(_ loadedSkills: inout [Skill]) -> Bool {
        var didChange = false

        let skillCount = loadedSkills.count
        loadedSkills.removeAll {
            deprecatedDefaultSkillNames.contains($0.name)
        }
        if loadedSkills.count != skillCount {
            didChange = true
        }

        loadedSkills = loadedSkills.map { skill in
            guard let defaultSkill = defaultSkillAliases[skill.name] else {
                return skill
            }

            var normalized = skill
            let updatedName = defaultSkill.rawValue
            let updatedSymbolName = defaultSkill.symbolName

            if normalized.name != updatedName {
                normalized.name = updatedName
                didChange = true
            }

            if normalized.symbolName != updatedSymbolName {
                normalized.symbolName = updatedSymbolName
                didChange = true
            }

            return normalized
        }

        let allSkillsAreDefaults = loadedSkills.allSatisfy {
            canonicalDefaultSkillNames.contains($0.name)
        }

        if allSkillsAreDefaults {
            let order = Dictionary(uniqueKeysWithValues: canonicalDefaultSkillNames.enumerated().map { ($1, $0) })
            let sortedSkills = loadedSkills.sorted {
                (order[$0.name] ?? .max) < (order[$1.name] ?? .max)
            }

            if sortedSkills.map(\.id) != loadedSkills.map(\.id) {
                loadedSkills = sortedSkills
                didChange = true
            }
        }

        return didChange
    }
}
