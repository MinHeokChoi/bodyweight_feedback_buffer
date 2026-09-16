import Foundation

enum DefaultSkillNormalizer {
    private static let canonicalDefaultSkillNames = DefaultSkill.allCases.map(\.rawValue)

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
        "Pia stretching": .piaStretching
    ]

    /// 옛 한국어 기본 기술 이름을 표준 이름으로 옮긴다.
    ///
    /// 이 이관은 "딥스"라는 기술이 하나뿐이던 옛 설치본을 위한 것이다.
    /// 사용자가 라이브러리에서 직접 "딥스"를 새로 만든 경우에는 이미 "Dips"가
    /// 따로 있으므로 이름을 바꾸면 안 된다. 바꾸면 똑같은 이름의 카드가 둘 생기고,
    /// 방금 적은 피드백이 어느 쪽에 붙었는지 알 수 없게 된다.
    static func normalize(_ loadedSkills: inout [Skill]) -> Bool {
        var didChange = false
        var takenNames = Set(loadedSkills.map(\.name))

        for index in loadedSkills.indices {
            let currentName = loadedSkills[index].name
            guard let defaultSkill = defaultSkillAliases[currentName] else { continue }
            let updatedName = defaultSkill.rawValue

            if currentName != updatedName {
                // 이름이 겹치면 사용자가 직접 만든 기술이다. 그대로 둔다.
                guard !takenNames.contains(updatedName) else { continue }
                takenNames.remove(currentName)
                takenNames.insert(updatedName)
                loadedSkills[index].name = updatedName
                didChange = true
            }

            if loadedSkills[index].symbolName != defaultSkill.symbolName {
                loadedSkills[index].symbolName = defaultSkill.symbolName
                didChange = true
            }
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
