import Foundation
import Observation

@MainActor
@Observable
final class FeedbackStore {
    private(set) var feedbacks: [Feedback] = [] {
        didSet { recomputeFeedbackDerivatives() }
    }
    private(set) var skills: [Skill] = []
    private(set) var quickPhrases: [String] = []

    private(set) var unarchivedFeedbacksScored: [(Feedback, Double)] = []
    private(set) var unarchivedCountsBySkill: [UUID: Int] = [:]
    private(set) var feedbackCountsBySkill: [UUID: Int] = [:]
    private(set) var lastActivityBySkill: [UUID: Date] = [:]

    private let feedbackRepository: FeedbackRepository
    private let settingsRepository: UserSettingsRepository
    private let persistenceScheduler: PersistenceScheduler
    private let reportIssue: (PersistenceIssue) -> Void

    private static let feedbackSchemaVersion = 1

    init(
        feedbackRepository: FeedbackRepository = FeedbackRepository(),
        settingsRepository: UserSettingsRepository = UserSettingsRepository(),
        persistenceScheduler: PersistenceScheduler = .background,
        reportIssue: @escaping (PersistenceIssue) -> Void = { _ in }
    ) {
        self.feedbackRepository = feedbackRepository
        self.settingsRepository = settingsRepository
        self.persistenceScheduler = persistenceScheduler
        self.reportIssue = reportIssue
        quickPhrases = settingsRepository.loadQuickPhrases()
        bootstrap()
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        do {
            var loadedSkills = try feedbackRepository.loadSkills()
            let loadedFeedbacks = try feedbackRepository.loadFeedbacks()

            let seededDefaults = loadedSkills.isEmpty
            if seededDefaults {
                loadedSkills = SampleData.defaultSkills()
            } else if DefaultSkillNormalizer.normalize(&loadedSkills) {
                try feedbackRepository.saveSkills(loadedSkills)
            }

            let validSkillIds = Set(loadedSkills.map(\.id))
            let prunedFeedbacks = loadedFeedbacks.filter { validSkillIds.contains($0.skillId) }
            let didPruneOrphans = prunedFeedbacks.count != loadedFeedbacks.count

            let priorSchemaVersion = settingsRepository.loadFeedbackSchemaVersion()
            let needsMigrationFlush = priorSchemaVersion < Self.feedbackSchemaVersion && !prunedFeedbacks.isEmpty

            skills = loadedSkills
            feedbacks = prunedFeedbacks

            if seededDefaults {
                persistSkills()
            }
            if didPruneOrphans || needsMigrationFlush {
                persistFeedbacks()
            }
            if priorSchemaVersion < Self.feedbackSchemaVersion {
                settingsRepository.saveFeedbackSchemaVersion(Self.feedbackSchemaVersion)
            }

            AppLog.lifecycle.info("feedback bootstrap ok skills=\(loadedSkills.count) feedbacks=\(prunedFeedbacks.count) pruned=\(didPruneOrphans)")
        } catch {
            skills = SampleData.defaultSkills()
            feedbacks = []
            AppLog.persistence.error("feedback bootstrap failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "데이터를 불러오지 못했습니다",
                error: error,
                recovery: "기본 기술 목록으로 시작합니다. 기존 기록 파일을 확인한 뒤 다시 시도해 주세요."
            )
        }
    }

    // MARK: - Derived

    var unarchivedFeedbacks: [Feedback] {
        unarchivedFeedbacksScored.map(\.0)
    }

    var topFeedback: Feedback? { unarchivedFeedbacksScored.first?.0 }

    func unarchivedFeedbacksScored(forSkillId skillId: UUID) -> [(Feedback, Double)] {
        unarchivedFeedbacksScored.filter { $0.0.skillId == skillId }
    }

    func unarchivedCount(forSkillId skillId: UUID) -> Int {
        unarchivedCountsBySkill[skillId] ?? 0
    }

    func feedbackCount(forSkillId skillId: UUID) -> Int {
        feedbackCountsBySkill[skillId] ?? 0
    }

    private func recomputeFeedbackDerivatives() {
        unarchivedFeedbacksScored = FeedbackScoring.sortedUnarchivedWithScores(feedbacks)
        var unarchived: [UUID: Int] = [:]
        var all: [UUID: Int] = [:]
        var last: [UUID: Date] = [:]
        for feedback in feedbacks {
            all[feedback.skillId, default: 0] += 1
            if feedback.archivedAt == nil {
                unarchived[feedback.skillId, default: 0] += 1
            }
            let date = feedback.referenceDate
            if let current = last[feedback.skillId] {
                if date > current { last[feedback.skillId] = date }
            } else {
                last[feedback.skillId] = date
            }
        }
        unarchivedCountsBySkill = unarchived
        feedbackCountsBySkill = all
        lastActivityBySkill = last
    }

    func hasSkill(named name: String) -> Bool {
        let normalizedName = normalizedSkillName(name)
        guard !normalizedName.isEmpty else { return false }
        return skills.contains { normalizedSkillName($0.name) == normalizedName }
    }

    // MARK: - Feedback intents

    func addFeedback(
        skill: Skill,
        title: String,
        note: String,
        importance: Int,
        category: FeedbackCategory = .skill
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = Feedback(
            skillId: skill.id,
            skillName: skill.name,
            title: trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            importance: importance,
            category: category
        )
        feedbacks.append(new)
        persistFeedbacks()
    }

    func updateFeedback(_ updated: Feedback) {
        guard let index = feedbacks.firstIndex(where: { $0.id == updated.id }) else { return }
        var copy = updated
        copy.updatedAt = .now
        feedbacks[index] = copy
        persistFeedbacks()
    }

    func archive(_ id: UUID) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[index].archivedAt = .now
        feedbacks[index].updatedAt = .now
        persistFeedbacks()
    }

    func unarchive(_ id: UUID) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        guard feedbacks[index].archivedAt != nil else { return }
        feedbacks[index].archivedAt = nil
        feedbacks[index].updatedAt = .now
        persistFeedbacks()
    }

    func markPracticed(_ id: UUID) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        feedbacks[index].unresolvedCount += 1
        feedbacks[index].lastReviewedAt = .now
        feedbacks[index].updatedAt = .now
        persistFeedbacks()
    }

    func delete(_ id: UUID) {
        feedbacks.removeAll { $0.id == id }
        persistFeedbacks()
    }

    // MARK: - Skill intents

    @discardableResult
    func addSkill(name: String, symbolName: String = "dumbbell.fill") -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !hasSkill(named: trimmed) else { return false }
        skills.append(Skill(name: trimmed, symbolName: symbolName))
        persistSkills()
        return true
    }

    func updateSkill(id: UUID, name: String, symbolName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = skills.firstIndex(where: { $0.id == id }) else { return }

        skills[index].name = trimmed
        skills[index].symbolName = symbolName

        var didUpdateFeedbacks = false
        for feedbackIndex in feedbacks.indices where feedbacks[feedbackIndex].skillId == id {
            feedbacks[feedbackIndex].skillName = trimmed
            didUpdateFeedbacks = true
        }

        persistSkills()
        if didUpdateFeedbacks {
            persistFeedbacks()
        }
    }

    func deleteSkill(_ id: UUID) {
        let beforeCount = skills.count
        skills.removeAll { $0.id == id }
        guard skills.count != beforeCount else { return }

        let feedbackCountBeforeDelete = feedbacks.count
        feedbacks.removeAll { $0.skillId == id }

        persistSkills()
        if feedbacks.count != feedbackCountBeforeDelete {
            persistFeedbacks()
        }
    }

    func moveSkill(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        moveItems(&skills, fromOffsets: source, toOffset: destination)
        persistSkills()
    }

    // MARK: - Quick phrases

    func updateQuickPhrases(_ phrases: [String]) {
        quickPhrases = phrases
        do {
            try settingsRepository.saveQuickPhrases(phrases)
        } catch {
            reportPersistenceIssue(
                title: "빠른 문구를 저장하지 못했습니다",
                error: error,
                recovery: "잠시 후 다시 시도해 주세요."
            )
        }
    }

    // MARK: - Persistence

    private func persistFeedbacks() {
        let snapshot = feedbacks
        let repository = feedbackRepository
        scheduleSave(
            { try repository.saveFeedbacks(snapshot) },
            failureTitle: "피드백을 저장하지 못했습니다"
        )
    }

    private func persistSkills() {
        let snapshot = skills
        let repository = feedbackRepository
        scheduleSave(
            { try repository.saveSkills(snapshot) },
            failureTitle: "기술 목록을 저장하지 못했습니다"
        )
    }

    private func normalizedSkillName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func scheduleSave(
        _ work: @escaping () throws -> Void,
        failureTitle: String
    ) {
        persistenceScheduler.perform { [weak self] in
            do {
                try work()
            } catch {
                AppLog.persistence.error("save failed: \(failureTitle, privacy: .public) — \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self?.reportPersistenceIssue(
                        title: failureTitle,
                        error: error,
                        recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
                    )
                }
            }
        }
    }

    private func reportPersistenceIssue(title: String, error: Error, recovery: String) {
        reportIssue(
            PersistenceIssue(
                title: title,
                message: "\(recovery)\n\n원인: \(error.localizedDescription)"
            )
        )
    }
}
