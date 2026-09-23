import Foundation
import Observation

@MainActor
@Observable
final class FeedbackStore {
    private(set) var feedbacks: [Feedback] = [] {
        didSet { recomputeFeedbackDerivatives() }
    }
    private(set) var skills: [Skill] = []
    /// 방금 한 해결·또 하기. 되돌리기 띠가 쓴다. 다음 변경이 생기면 사라진다.
    private(set) var undoableAction: UndoableAction?

    private(set) var unarchivedCountsBySkill: [UUID: Int] = [:]
    private(set) var feedbackCountsBySkill: [UUID: Int] = [:]
    private(set) var lastActivityBySkill: [UUID: Date] = [:]

    private let feedbackRepository: FeedbackRepository
    private let settingsRepository: UserSettingsRepository
    private let persistenceScheduler: PersistenceScheduler
    private let reportIssue: (PersistenceIssue) -> Void

    /// 2: 점수 정렬을 없애고 배열 순서를 화면 순서로 쓰기 시작했다.
    private static let feedbackSchemaVersion = 2

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
        settingsRepository.removeRetiredValues()
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
            var prunedFeedbacks = loadedFeedbacks.filter { validSkillIds.contains($0.skillId) }
            let didPruneOrphans = prunedFeedbacks.count != loadedFeedbacks.count

            let priorSchemaVersion = settingsRepository.loadFeedbackSchemaVersion()
            // 점수제 시절 배열은 추가된 순서라 오래된 것이 앞이다. 배열 순서를 화면
            // 순서로 쓰기 시작하면서 한 번만 마지막으로 손댄 순으로 세운다.
            if priorSchemaVersion < 2 {
                prunedFeedbacks = FeedbackOrdering.migratedOrder(prunedFeedbacks)
            }
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
                title: "데이터를 불러오지 못했어요",
                error: error,
                recovery: "기본 기술 목록으로 시작해요. 기존 기록 파일을 확인한 뒤 다시 시도해 주세요."
            )
        }
    }

    // MARK: - Derived

    /// 해결하지 않은 피드백. 저장된 순서 그대로다 — 순서는 사용자의 행동이 정한다.
    var unarchivedFeedbacks: [Feedback] {
        feedbacks.filter { $0.archivedAt == nil }
    }

    func unarchivedFeedbacks(forSkillId skillId: UUID) -> [Feedback] {
        unarchivedFeedbacks.filter { $0.skillId == skillId }
    }

    /// 오늘 할 것. 날이 바뀌면 저절로 비워진다.
    func todayFeedbacks(now: Date = .now) -> [Feedback] {
        feedbacks.filter { $0.isInToday(now: now) }
    }

    /// 오늘 할 것에 담지 않은 나머지. 버퍼 아래쪽 목록이다.
    func backlogFeedbacks(now: Date = .now) -> [Feedback] {
        feedbacks.filter { $0.archivedAt == nil && !$0.isInToday(now: now) }
    }

    /// 해결하지 않은 피드백이 하나라도 있는 기술. 기술별 필터 칩에 쓴다.
    var skillsWithActiveFeedback: [Skill] {
        skills.filter { (unarchivedCountsBySkill[$0.id] ?? 0) > 0 }
    }

    func unarchivedCount(forSkillId skillId: UUID) -> Int {
        unarchivedCountsBySkill[skillId] ?? 0
    }

    func feedbackCount(forSkillId skillId: UUID) -> Int {
        feedbackCountsBySkill[skillId] ?? 0
    }

    private func recomputeFeedbackDerivatives() {
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

    @discardableResult
    func addFeedback(
        skill: Skill,
        title: String,
        note: String,
        importance: Int,
        category: FeedbackCategory = .skill
    ) -> Feedback? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let new = Feedback(
            skillId: skill.id,
            skillName: skill.name,
            title: trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            importance: importance,
            category: category
        )
        // 방금 적은 것은 맨 위. 점수제에서는 늘 바닥에 깔려 안 보였다.
        feedbacks.insert(new, at: 0)
        persistFeedbacks()
        return new
    }

    func updateFeedback(_ updated: Feedback) {
        guard let index = feedbacks.firstIndex(where: { $0.id == updated.id }) else { return }
        var copy = updated
        copy.updatedAt = .now
        feedbacks[index] = copy
        persistFeedbacks()
    }

    func archive(_ id: UUID, now: Date = .now) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        let previous = feedbacks[index]
        feedbacks[index].archivedAt = now
        feedbacks[index].updatedAt = now
        feedbacks[index].todayAddedAt = nil
        persistFeedbacks()
        rememberForUndo(.archive, previous: previous, at: index, now: now)
    }

    func unarchive(_ id: UUID) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        guard feedbacks[index].archivedAt != nil else { return }
        feedbacks[index].archivedAt = nil
        feedbacks[index].updatedAt = .now
        // 다시 꺼낸 것은 지금 손댄 것이다. 맨 위로 둔다.
        feedbacks = FeedbackOrdering.movingToFront(id, in: feedbacks)
        persistFeedbacks()
    }

    /// "또 하기". 연습 횟수를 올리고 맨 위로 보낸다.
    /// 오늘 할 것에 있었다면 오늘 몫은 끝난 것이라 거기서 조용히 빠진다.
    func markPracticed(_ id: UUID, now: Date = .now) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }) else { return }
        let previous = feedbacks[index]
        var updated = feedbacks
        updated[index].unresolvedCount += 1
        updated[index].lastReviewedAt = now
        updated[index].updatedAt = now
        updated[index].todayAddedAt = nil
        feedbacks = FeedbackOrdering.movingToFront(id, in: updated)
        persistFeedbacks()
        rememberForUndo(.practiced, previous: previous, at: index, now: now)
    }

    // MARK: - 되돌리기

    struct UndoableAction: Identifiable, Equatable {
        enum Kind: Equatable {
            case archive
            case practiced
        }

        let id = UUID()
        let kind: Kind
        /// 누르기 전의 피드백. 자리·오늘 할 것·횟수·마지막으로 한 날을 모두 담고 있다.
        let previous: Feedback
        /// 누르기 전 배열 속 자리
        let previousIndex: Int
        let expiresAt: Date
    }

    /// 되돌리기 띠가 떠 있는 시간
    static let undoWindow: TimeInterval = 5

    private func rememberForUndo(_ kind: UndoableAction.Kind, previous: Feedback, at index: Int, now: Date) {
        undoableAction = UndoableAction(
            kind: kind,
            previous: previous,
            previousIndex: index,
            expiresAt: now.addingTimeInterval(Self.undoWindow)
        )
    }

    /// 방금 한 해결·또 하기를 되돌린다. 누르기 전 그 자리에 그 모습 그대로 돌려놓는다.
    ///
    /// 그 사이에 다른 변경이 있었다면 이미 사라져 있으므로(`persistFeedbacks`),
    /// 되돌리기가 다른 변경까지 되감는 일은 없다.
    func undoLastAction() {
        guard let action = undoableAction else { return }
        undoableAction = nil
        guard let current = feedbacks.firstIndex(where: { $0.id == action.previous.id }) else { return }
        var restored = feedbacks
        restored.remove(at: current)
        restored.insert(action.previous, at: min(action.previousIndex, restored.count))
        feedbacks = restored
        persistFeedbacks()
    }

    /// 저장하지 않는 변경(필터 중 임시로 끌기)도 되돌리기를 끝낸다.
    /// 되살린 카드가 새로 늘어놓은 순서 어디에 들어갈지 알 수 없기 때문이다.
    func discardUndo() {
        undoableAction = nil
    }

    /// 띠가 사라질 때. 그 사이 새 동작이 생겼다면 그것은 건드리지 않는다.
    func expireUndo(_ id: UUID) {
        guard undoableAction?.id == id else { return }
        undoableAction = nil
    }

    // MARK: - 오늘 할 것

    func addToToday(_ id: UUID, now: Date = .now) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }),
              feedbacks[index].archivedAt == nil,
              !feedbacks[index].isInToday(now: now) else { return }
        feedbacks[index].todayAddedAt = now
        persistFeedbacks()
    }

    func removeFromToday(_ id: UUID) {
        guard let index = feedbacks.firstIndex(where: { $0.id == id }),
              feedbacks[index].todayAddedAt != nil else { return }
        feedbacks[index].todayAddedAt = nil
        persistFeedbacks()
    }

    // MARK: - 순서

    /// 화면에 보이는 목록(`visibleIds`) 안에서 끌어 옮긴 것을 저장한다.
    /// 보이지 않는 항목(보관한 것, 다른 구역)의 자리는 건드리지 않는다.
    func moveFeedbacks(visibleIds: [UUID], fromOffsets source: IndexSet, toOffset destination: Int) {
        let reordered = FeedbackOrdering.reordering(
            feedbacks,
            visibleIds: visibleIds,
            fromOffsets: source,
            toOffset: destination
        )
        guard reordered.map(\.id) != feedbacks.map(\.id) else { return }
        feedbacks = reordered
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

    // MARK: - Persistence

    /// 피드백을 바꾸는 모든 동작이 여기를 거친다. 그래서 되돌리기도 여기서 버린다 —
    /// 되돌리기는 바로 다음 변경 전까지만 유효하다. 해결·또 하기는 저장한 뒤에 다시 남긴다.
    private func persistFeedbacks() {
        undoableAction = nil
        let snapshot = feedbacks
        let repository = feedbackRepository
        scheduleSave(
            { try repository.saveFeedbacks(snapshot) },
            failureTitle: "피드백을 저장하지 못했어요"
        )
    }

    private func persistSkills() {
        let snapshot = skills
        let repository = feedbackRepository
        scheduleSave(
            { try repository.saveSkills(snapshot) },
            failureTitle: "기술 목록을 저장하지 못했어요"
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
